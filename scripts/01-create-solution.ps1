. "$PSScriptRoot\dv.ps1"
$pubId = 'fe15ae15-ed16-448b-a014-3aa08124d0d0'
$existing = (Invoke-Dv -Method GET -Path "/api/data/v9.2/solutions?`$select=solutionid,uniquename,friendlyname,version&`$filter=uniquename eq 'DependentPicklists'").value
if ($existing) {
  Write-Host "Solution exists:" -ForegroundColor Yellow
  $existing | Format-List solutionid,uniquename,friendlyname,version
  return
}
$body = @{
  uniquename = 'DependentPicklists'
  friendlyname = 'Dependent Picklists'
  version = '1.0.0.0'
  description = 'Salesforce-style dependent picklists for model-driven apps'
  'publisherid@odata.bind' = "/publishers($pubId)"
}
$created = Invoke-Dv -Method POST -Path '/api/data/v9.2/solutions' -Body $body
Write-Host "Created solution:" -ForegroundColor Green
$created | Select-Object solutionid, uniquename, version
