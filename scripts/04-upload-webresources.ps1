. "$PSScriptRoot\dv.ps1"

$solutionUniqueName = 'DependentPicklists'

# WebResourceType values:
# 1 HTML, 3 JavaScript
$resources = @(
  @{ Name='mau_DependentPicklistAdmin.html';  Display='Dependent Picklists Admin'; Type=1; Path="$PSScriptRoot\..\webresources\mau_DependentPicklistAdmin.html" },
  @{ Name='mau_DependentPicklistRuntime.js'; Display='Dependent Picklists Runtime'; Type=3; Path="$PSScriptRoot\..\webresources\mau_DependentPicklistRuntime.js" }
)

foreach ($r in $resources) {
  $bytes = [System.IO.File]::ReadAllBytes($r.Path)
  $b64 = [Convert]::ToBase64String($bytes)

  $existing = (Invoke-Dv -Method GET -Path "/api/data/v9.2/webresourceset?`$select=webresourceid,name&`$filter=name eq '$($r.Name)'").value
  if ($existing) {
    $id = $existing[0].webresourceid
    Write-Host "Updating $($r.Name) ($id)" -ForegroundColor Cyan
    Invoke-Dv -Method PATCH -Path "/api/data/v9.2/webresourceset($id)" -Body @{
      content = $b64
      displayname = $r.Display
    } | Out-Null
  } else {
    Write-Host "Creating $($r.Name)" -ForegroundColor Green
    $created = Invoke-Dv -Method POST -Path "/api/data/v9.2/webresourceset" -Body @{
      name = $r.Name
      displayname = $r.Display
      webresourcetype = $r.Type
      content = $b64
    } -ExtraHeaders @{ 'MSCRM.SolutionUniqueName' = $solutionUniqueName }
    Write-Host "  id: $($created.webresourceid)"
  }
}

Write-Host "Publishing all customizations..." -ForegroundColor Cyan
Invoke-Dv -Method POST -Path "/api/data/v9.2/PublishAllXml" -Body @{} | Out-Null
Write-Host "Published." -ForegroundColor Green
