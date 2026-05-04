. "$PSScriptRoot\dv.ps1"

$formId = '4a63c8d1-6c1e-48ec-9db4-3e6c7155334c'
$libraryName  = 'mau_DependentPicklistRuntime.js'
$functionName = 'MauDependentPicklists.onFormLoad'

$form = Invoke-Dv -Method GET -Path "/api/data/v9.2/systemforms($formId)?`$select=name,formxml,iscustomizable,ismanaged,formidunique"
Write-Host "Name: $($form.name)"
Write-Host "iscustomizable: $($form.iscustomizable.Value)"
Write-Host "ismanaged: $($form.ismanaged)"
Write-Host "formidunique: $($form.formidunique)"

[xml]$xml = $form.formxml

# Add library
$libs = $xml.SelectSingleNode('/form/formLibraries')
if (-not $libs) { $libs = $xml.CreateElement('formLibraries'); $xml.DocumentElement.PrependChild($libs) | Out-Null }
if (-not $libs.SelectSingleNode("Library[@name='$libraryName']")) {
  $lib = $xml.CreateElement('Library')
  $lib.SetAttribute('name', $libraryName)
  $lib.SetAttribute('libraryUniqueId', [Guid]::NewGuid().ToString('B'))
  $libs.AppendChild($lib) | Out-Null
}

$events = $xml.SelectSingleNode('/form/events')
if (-not $events) { $events = $xml.CreateElement('events'); $xml.DocumentElement.AppendChild($events) | Out-Null }
$onload = $events.SelectSingleNode("event[@name='onload']")
if (-not $onload) {
  $onload = $xml.CreateElement('event')
  $onload.SetAttribute('name','onload'); $onload.SetAttribute('application','false'); $onload.SetAttribute('active','false')
  $h = $xml.CreateElement('Handlers'); $onload.AppendChild($h) | Out-Null
  $events.AppendChild($onload) | Out-Null
}
$handlers = $onload.SelectSingleNode('Handlers')
if (-not $handlers.SelectSingleNode("Handler[@functionName='$functionName' and @libraryName='$libraryName']")) {
  $h = $xml.CreateElement('Handler')
  $h.SetAttribute('functionName', $functionName)
  $h.SetAttribute('libraryName', $libraryName)
  $h.SetAttribute('handlerUniqueId', [Guid]::NewGuid().ToString('B'))
  $h.SetAttribute('enabled','true'); $h.SetAttribute('parameters',''); $h.SetAttribute('passExecutionContext','true')
  $handlers.AppendChild($h) | Out-Null
}

$payload = @{ formxml = $xml.OuterXml }
Write-Host "OUR XML library count: $((([xml]$payload.formxml).SelectNodes("/form/formLibraries/Library[@name='$libraryName']")).Count)" -ForegroundColor Magenta
Write-Host "PATCHing form..." -ForegroundColor Cyan
$resp = Invoke-Dv -Method PATCH -Path "/api/data/v9.2/systemforms($formId)" -Body $payload -ExtraHeaders @{ 'MSCRM.SolutionUniqueName' = 'DependentPicklists' }
Write-Host "PATCH response keys: $($resp.PSObject.Properties.Name -join ', ')" -ForegroundColor Cyan

# Re-fetch
$form2 = Invoke-Dv -Method GET -Path "/api/data/v9.2/systemforms($formId)?`$select=formxml"
[xml]$xml2 = $form2.formxml
$libCount = ($xml2.SelectNodes("/form/formLibraries/Library[@name='$libraryName']")).Count
$hCount = ($xml2.SelectNodes("/form/events/event[@name='onload']/Handlers/Handler[@functionName='$functionName']")).Count
Write-Host "After PATCH: library count = $libCount, handler count = $hCount"
