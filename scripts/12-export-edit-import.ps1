. "$PSScriptRoot\dv.ps1"

# 1) Export current unmanaged DependentPicklists solution (already has the two forms added)
$exportPath = Join-Path $env:TEMP "DependentPicklists_export_$([Guid]::NewGuid().ToString('N')).zip"
Write-Host "Exporting solution..." -ForegroundColor Cyan
& pac solution export --name DependentPicklists --path $exportPath --overwrite
if (-not (Test-Path $exportPath)) { throw "Export failed" }

# 2) Unpack
$unpackDir = Join-Path $env:TEMP "DependentPicklists_unpack_$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $unpackDir | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($exportPath, $unpackDir)
Write-Host "Unpacked to $unpackDir" -ForegroundColor Cyan

# 3) Edit customizations.xml — find the systemform nodes and inject Library + Handler
$custPath = Join-Path $unpackDir 'customizations.xml'
[xml]$cust = Get-Content -Raw -Path $custPath

$libraryName  = 'mau_DependentPicklistRuntime.js'
$functionName = 'MauDependentPicklists.onFormLoad'

$forms = $cust.SelectNodes("//systemform")
Write-Host "Forms found in solution export: $($forms.Count)"
$targetIds = @('{915f6055-2e07-4276-ae08-2b96c8d02c57}','{4a63c8d1-6c1e-48ec-9db4-3e6c7155334c}','{cd0d48a0-10c6-ec11-a7b5-000d3a58b83a}')
foreach ($sf in $forms) {
  if ($targetIds -notcontains $sf.formid) { Write-Host "  (skip) $($sf.formid)"; continue }
  $formNode = $sf.SelectSingleNode('form')
  if (-not $formNode) { continue }
  $name = $sf.SelectSingleNode('LocalizedNames/LocalizedName/@description')
  Write-Host "  Editing form $($sf.formid)" -ForegroundColor Cyan

  # formLibraries
  $libs = $formNode.SelectSingleNode('formLibraries')
  if (-not $libs) { $libs = $cust.CreateElement('formLibraries'); $formNode.PrependChild($libs) | Out-Null }
  if (-not $libs.SelectSingleNode("Library[@name='$libraryName']")) {
    $lib = $cust.CreateElement('Library')
    $lib.SetAttribute('name', $libraryName)
    $lib.SetAttribute('libraryUniqueId', [Guid]::NewGuid().ToString('B'))
    $lib.SetAttribute('solutionaction', 'Added')
    $libs.AppendChild($lib) | Out-Null
    Write-Host "    + Library added"
  } else {
    $existingLib = $libs.SelectSingleNode("Library[@name='$libraryName']")
    if (-not $existingLib.GetAttribute('solutionaction')) { $existingLib.SetAttribute('solutionaction','Added'); Write-Host "    ~ Library marked Added" }
    else { Write-Host "    = Library present" }
  }

  $events = $formNode.SelectSingleNode('events')
  if (-not $events) { $events = $cust.CreateElement('events'); $formNode.AppendChild($events) | Out-Null }
  $onload = $events.SelectSingleNode("event[@name='onload']")
  if (-not $onload) {
    $onload = $cust.CreateElement('event')
    $onload.SetAttribute('name','onload'); $onload.SetAttribute('application','false'); $onload.SetAttribute('active','false')
    $onload.SetAttribute('solutionaction','Added')
    $h = $cust.CreateElement('Handlers'); $onload.AppendChild($h) | Out-Null
    $events.AppendChild($onload) | Out-Null
  }
  $handlers = $onload.SelectSingleNode('Handlers')
  if (-not $handlers.SelectSingleNode("Handler[@functionName='$functionName' and @libraryName='$libraryName']")) {
    $h = $cust.CreateElement('Handler')
    $h.SetAttribute('functionName', $functionName)
    $h.SetAttribute('libraryName', $libraryName)
    $h.SetAttribute('handlerUniqueId', [Guid]::NewGuid().ToString('B'))
    $h.SetAttribute('enabled','true'); $h.SetAttribute('parameters',''); $h.SetAttribute('passExecutionContext','true')
    $h.SetAttribute('solutionaction','Added')
    $handlers.AppendChild($h) | Out-Null
    Write-Host "    + Handler added"
  } else {
    $existingH = $handlers.SelectSingleNode("Handler[@functionName='$functionName' and @libraryName='$libraryName']")
    if (-not $existingH.GetAttribute('solutionaction')) { $existingH.SetAttribute('solutionaction','Added'); Write-Host "    ~ Handler marked Added" }
    else { Write-Host "    = Handler present" }
  }
  if (-not $onload.GetAttribute('solutionaction')) { $onload.SetAttribute('solutionaction','Added') }
  if (-not $events.GetAttribute('solutionaction')) { $events.SetAttribute('solutionaction','Added') }
}

# Save customizations.xml (UTF8 no BOM)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$xmlText = $cust.OuterXml
[System.IO.File]::WriteAllText($custPath, $xmlText, $utf8)

# Bump solution version (optional)
$solPath = Join-Path $unpackDir 'solution.xml'
[xml]$sol = Get-Content -Raw -Path $solPath
$verNode = $sol.SelectSingleNode('//SolutionManifest/Version')
if ($verNode) {
  $parts = $verNode.InnerText.Split('.')
  if ($parts.Length -ge 4) { $parts[3] = ([int]$parts[3] + 1).ToString() }
  $verNode.InnerText = ($parts -join '.')
  Write-Host "New version: $($verNode.InnerText)"
}
[System.IO.File]::WriteAllText($solPath, $sol.OuterXml, $utf8)

# 4) Re-zip
$importZip = Join-Path $env:TEMP "DependentPicklists_import_$([Guid]::NewGuid().ToString('N')).zip"
[System.IO.Compression.ZipFile]::CreateFromDirectory($unpackDir, $importZip)
Write-Host "Repacked: $importZip" -ForegroundColor Cyan

# 5) Import
Write-Host "Importing..." -ForegroundColor Cyan
& pac solution import --path $importZip --publish-changes --force-overwrite
