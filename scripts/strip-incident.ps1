# strip-incident.ps1
# Removes the `Incident` (Case) entity, its forms, and all MissingDependency
# nodes from the DependentPicklists solution zips, then bumps the version.
#
# Background: when the Case entity was added to the source environment's
# DependentPicklists solution (originally to register the dependent-picklist
# form script for testing), Dataverse serialized the FULL Case form XML.
# That form XML references every Field Service / Customer Portal / unmanaged
# extension on the source org (msdyn_*, adx_*, crdc5_*, ...), turning each
# into a hard import dependency. The framework itself does NOT need the
# Incident entity in the package -- the runtime web resource is registered
# per-form by the admin UI / by the customer at install time.
#
# This script produces a clean, dependency-free framework package.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot   = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $repoRoot 'releases'
$newVersion = '1.1.13.0'

function Strip-Zip {
    param([string]$ZipPath, [string]$NewVersion)

    Write-Host "==> $ZipPath" -ForegroundColor Cyan
    $tmp = Join-Path $env:TEMP ("strip_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    [IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $tmp)

    $custPath = Join-Path $tmp 'customizations.xml'
    $solPath  = Join-Path $tmp 'solution.xml'

    # ---- customizations.xml: drop the Incident entity ----
    [xml]$cust = Get-Content -Raw -Path $custPath
    $removed = 0
    foreach ($e in @($cust.SelectNodes('/ImportExportXml/Entities/Entity'))) {
        $name = $e.SelectSingleNode('Name').InnerText
        if ($name -ieq 'Incident') {
            [void]$e.ParentNode.RemoveChild($e)
            $removed++
        }
    }
    Write-Host "  customizations.xml: removed $removed Incident <Entity> node(s)"

    # ---- solution.xml: drop incident RootComponent + all MissingDependency ----
    [xml]$sol = Get-Content -Raw -Path $solPath

    $rcRemoved = 0
    foreach ($rc in @($sol.SelectNodes('//RootComponent'))) {
        if ($rc.schemaName -ieq 'incident') {
            [void]$rc.ParentNode.RemoveChild($rc)
            $rcRemoved++
        }
    }
    Write-Host "  solution.xml: removed $rcRemoved incident RootComponent(s)"

    $mdRemoved = 0
    foreach ($md in @($sol.SelectNodes('//MissingDependency'))) {
        [void]$md.ParentNode.RemoveChild($md)
        $mdRemoved++
    }
    Write-Host "  solution.xml: removed $mdRemoved MissingDependency node(s)"

    # If MissingDependencies parent is now empty, leave it (Dataverse tolerates it).

    # Bump version
    $verNode = $sol.SelectSingleNode('//SolutionManifest/Version')
    $oldVer = $verNode.InnerText
    $verNode.InnerText = $NewVersion
    Write-Host "  solution.xml: version $oldVer -> $NewVersion"

    # Save as UTF-8 without BOM
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($custPath, $cust.OuterXml, $utf8)
    [IO.File]::WriteAllText($solPath,  $sol.OuterXml,  $utf8)

    # Re-zip in place
    $newZip = Join-Path $env:TEMP ("strip_" + [guid]::NewGuid().ToString('N') + ".zip")
    [IO.Compression.ZipFile]::CreateFromDirectory($tmp, $newZip)
    Copy-Item $newZip $ZipPath -Force
    Remove-Item -Recurse -Force $tmp
    Remove-Item -Force $newZip
    Write-Host "  repacked OK ($([math]::Round((Get-Item $ZipPath).Length/1KB,1)) KB)" -ForegroundColor Green
}

foreach ($name in 'DependentPicklists.zip','DependentPicklists_managed.zip') {
    Strip-Zip -ZipPath (Join-Path $releaseDir $name) -NewVersion $newVersion
}

Write-Host "`nDone. Both zips are now framework-only at version $newVersion." -ForegroundColor Green
