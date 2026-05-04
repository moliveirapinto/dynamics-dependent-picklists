. "$PSScriptRoot\dv.ps1"
$f = Invoke-Dv -Method GET -Path "/api/data/v9.2/systemforms(4a63c8d1-6c1e-48ec-9db4-3e6c7155334c)?`$select=name,formjson"
Write-Host "formjson length: $($f.formjson.Length)"
if ($f.formjson) {
  $f.formjson.Substring(0, [Math]::Min(2000, $f.formjson.Length)) | Out-Host
}
Write-Host "---"
Write-Host "Contains 'mau_DependentPicklistRuntime':"
Write-Host ($f.formjson -like '*mau_DependentPicklistRuntime*')
Write-Host "Contains 'MauDependentPicklists':"
Write-Host ($f.formjson -like '*MauDependentPicklists*')
