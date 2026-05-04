. "$PSScriptRoot\dv.ps1"

$solutionUniqueName = 'DependentPicklists'

# componenttype enum: 1 = Entity, 61 = WebResource
# AddSolutionComponent action handles dependencies for entities (with all subcomponents).

# 1) Resolve component IDs
$entity = Invoke-Dv -Method GET -Path "/api/data/v9.2/EntityDefinitions(LogicalName='mau_dependentpicklistrule')?`$select=MetadataId"
$entityId = $entity.MetadataId
Write-Host "Entity MetadataId: $entityId" -ForegroundColor Cyan

$wrs = (Invoke-Dv -Method GET -Path "/api/data/v9.2/webresourceset?`$select=webresourceid,name&`$filter=name eq 'mau_DependentPicklistAdmin.html' or name eq 'mau_DependentPicklistRuntime.js'").value

function Add-Component {
  param([string]$ComponentId, [int]$ComponentType, [bool]$IncludeSubcomponents = $false)
  $body = @{
    ComponentId = $ComponentId
    ComponentType = $ComponentType
    SolutionUniqueName = $solutionUniqueName
    AddRequiredComponents = $false
    DoNotIncludeSubcomponents = (-not $IncludeSubcomponents)
    IncludedComponentSettingsValues = $null
  }
  try {
    Invoke-Dv -Method POST -Path "/api/data/v9.2/AddSolutionComponent" -Body $body | Out-Null
    Write-Host "  added component $ComponentId (type $ComponentType)" -ForegroundColor Green
  } catch {
    Write-Host "  (add failed or already present) $ComponentId type $ComponentType" -ForegroundColor Yellow
  }
}

Add-Component -ComponentId $entityId -ComponentType 1 -IncludeSubcomponents $true
foreach ($w in $wrs) {
  Add-Component -ComponentId $w.webresourceid -ComponentType 61 -IncludeSubcomponents $false
}

Write-Host "Done." -ForegroundColor Green
