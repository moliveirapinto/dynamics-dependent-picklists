$dir = Get-ChildItem $env:TEMP -Directory -Filter "DependentPicklists_unpack_*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host "Inspecting: $($dir.FullName)"
[xml]$x = Get-Content -Raw (Join-Path $dir.FullName 'customizations.xml')
$caseForm = $x.SelectSingleNode("//systemform[formid='{4a63c8d1-6c1e-48ec-9db4-3e6c7155334c}']")
Write-Host "Found case form? $($null -ne $caseForm)"
if ($caseForm) {
  Write-Host "Libraries in saved customizations.xml:"
  $caseForm.SelectNodes(".//formLibraries/Library") | ForEach-Object { Write-Host "  - $($_.name)" }
  Write-Host "Handlers:"
  $caseForm.SelectNodes(".//Handlers/Handler") | ForEach-Object { Write-Host "  - $($_.functionName) :: $($_.libraryName)" }
}
