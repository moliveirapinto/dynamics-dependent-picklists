. "$PSScriptRoot\dv.ps1"
$form = Invoke-Dv -Method GET -Path "/api/data/v9.2/systemforms(4a63c8d1-6c1e-48ec-9db4-3e6c7155334c)?`$select=name,formxml"
[xml]$xml = $form.formxml
Write-Host "Form: $($form.name)"
Write-Host "Libraries:"
$xml.SelectNodes('/form/formLibraries/Library') | ForEach-Object { Write-Host "  - $($_.name)" }
Write-Host "OnLoad handlers:"
$xml.SelectNodes("/form/events/event[@name='onload']/Handlers/Handler") | ForEach-Object { Write-Host "  - $($_.functionName) :: $($_.libraryName)" }
Write-Host "All events:"
$xml.SelectNodes("/form/events/event") | ForEach-Object { Write-Host "  event: $($_.name)" }
