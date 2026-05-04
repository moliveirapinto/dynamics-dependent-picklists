. "$PSScriptRoot\dv.ps1"

$entity = 'incident'
$cField = 'caseorigincode'
$dField = 'casetypecode'

$rules = @(
  @{ cVal = 1; allowed = @(1,2) },   # Phone -> Question, Problem
  @{ cVal = 2; allowed = @(3) },     # Email -> Request
  @{ cVal = 3; allowed = @(1,3) }    # Web   -> Question, Request
)

# Clean any existing rows for this triple
$existing = (Invoke-Dv -Method GET -Path "/api/data/v9.2/mau_dependentpicklistrules?`$select=mau_dependentpicklistruleid,mau_controllingoptionvalue&`$filter=mau_entitylogicalname eq '$entity' and mau_controllingfieldlogicalname eq '$cField' and mau_dependentfieldlogicalname eq '$dField'").value
foreach ($e in $existing) {
  Write-Host "Deleting existing row for cVal=$($e.mau_controllingoptionvalue)" -ForegroundColor Yellow
  Invoke-Dv -Method DELETE -Path "/api/data/v9.2/mau_dependentpicklistrules($($e.mau_dependentpicklistruleid))" | Out-Null
}

foreach ($r in $rules) {
  $body = @{
    mau_name = "$entity|$cField=$($r.cVal)->$dField"
    mau_entitylogicalname = $entity
    mau_controllingfieldlogicalname = $cField
    mau_dependentfieldlogicalname = $dField
    mau_controllingoptionvalue = $r.cVal
    mau_alloweddependentoptionvalues = (ConvertTo-Json -InputObject @($r.allowed) -Compress)
    mau_isactive = $true
  }
  $created = Invoke-Dv -Method POST -Path "/api/data/v9.2/mau_dependentpicklistrules" -Body $body
  Write-Host "Created rule: cVal=$($r.cVal) allowed=$($r.allowed -join ',') id=$($created.mau_dependentpicklistruleid)" -ForegroundColor Green
}
