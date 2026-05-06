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
$newVersion = '1.1.14.0'

function Strip-Zip {
    param([string]$ZipPath, [string]$NewVersion)

    Write-Host "==> $ZipPath" -ForegroundColor Cyan
    $utf8 = New-Object System.Text.UTF8Encoding($false)

    # ---- Read every entry from the source zip into memory, preserving the
    #      ORIGINAL FullName (forward-slash separators required by Dataverse).
    $src = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    $entries = [ordered]@{}
    try {
        foreach ($e in $src.Entries) {
            # Drop bogus single-letter junk entries that occasionally appear
            # in pac-exported zips (e.g. an empty 'W' sibling of WebResources/).
            if ($e.FullName -match '^[A-Za-z]$') {
                Write-Host "  dropping junk entry '$($e.FullName)' ($($e.Length) bytes)"
                continue
            }
            if ($entries.Contains($e.FullName)) { continue }   # dedupe
            $ms = New-Object IO.MemoryStream
            $s  = $e.Open(); $s.CopyTo($ms); $s.Close()
            $entries[$e.FullName] = $ms.ToArray()
        }
    } finally { $src.Dispose() }

    # ---- customizations.xml: drop the Incident entity ----
    $custBytes = $entries['customizations.xml']
    $custText  = [Text.Encoding]::UTF8.GetString($custBytes)
    if ($custText.Length -gt 0 -and [int][char]$custText[0] -eq 0xFEFF) { $custText = $custText.Substring(1) }
    [xml]$cust = $custText
    $removed = 0
    foreach ($e in @($cust.SelectNodes('/ImportExportXml/Entities/Entity'))) {
        $name = $e.SelectSingleNode('Name').InnerText
        if ($name -ieq 'Incident') {
            [void]$e.ParentNode.RemoveChild($e)
            $removed++
        }
    }
    Write-Host "  customizations.xml: removed $removed Incident <Entity> node(s)"
    $entries['customizations.xml'] = $utf8.GetBytes($cust.OuterXml)

    # ---- solution.xml: drop incident RootComponent + all MissingDependency, bump version ----
    $solBytes = $entries['solution.xml']
    $solText  = [Text.Encoding]::UTF8.GetString($solBytes)
    if ($solText.Length -gt 0 -and [int][char]$solText[0] -eq 0xFEFF) { $solText = $solText.Substring(1) }
    [xml]$sol = $solText

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

    $verNode = $sol.SelectSingleNode('//SolutionManifest/Version')
    $oldVer = $verNode.InnerText
    $verNode.InnerText = $NewVersion
    Write-Host "  solution.xml: version $oldVer -> $NewVersion"
    $entries['solution.xml'] = $utf8.GetBytes($sol.OuterXml)

    # ---- Write a fresh zip preserving original entry names (forward slashes) ----
    $newZip = Join-Path $env:TEMP ("strip_" + [guid]::NewGuid().ToString('N') + ".zip")
    $z = [IO.Compression.ZipFile]::Open($newZip, 'Create')
    try {
        foreach ($k in $entries.Keys) {
            $ne = $z.CreateEntry($k, [IO.Compression.CompressionLevel]::Optimal)
            $os = $ne.Open()
            $bytes = $entries[$k]
            $os.Write($bytes, 0, $bytes.Length)
            $os.Close()
        }
    } finally { $z.Dispose() }

    Copy-Item $newZip $ZipPath -Force
    Remove-Item -Force $newZip
    Write-Host "  repacked OK ($([math]::Round((Get-Item $ZipPath).Length/1KB,1)) KB)" -ForegroundColor Green
}

foreach ($name in 'DependentPicklists.zip','DependentPicklists_managed.zip') {
    Strip-Zip -ZipPath (Join-Path $releaseDir $name) -NewVersion $newVersion
}

Write-Host "`nDone. Both zips are now framework-only at version $newVersion." -ForegroundColor Green
