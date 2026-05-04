. "$PSScriptRoot\dv.ps1"

$solutionUniqueName = 'DependentPicklists'
$schemaName = 'mau_dependentpicklistrule'

# Check if it already exists
try {
  $existing = Invoke-Dv -Method GET -Path "/api/data/v9.2/EntityDefinitions(LogicalName='$schemaName')?`$select=LogicalName,SchemaName,MetadataId"
  Write-Host "Table $schemaName already exists (MetadataId=$($existing.MetadataId))" -ForegroundColor Yellow
  return
} catch {
  Write-Host "Table not found, creating..." -ForegroundColor Cyan
}

$entityBody = @{
  '@odata.type'              = 'Microsoft.Dynamics.CRM.EntityMetadata'
  SchemaName                 = 'mau_DependentPicklistRule'
  LogicalName                = $schemaName
  DisplayName                = @{
    LocalizedLabels = @(@{ Label = 'Dependent Picklist Rule'; LanguageCode = 1033 })
  }
  DisplayCollectionName      = @{
    LocalizedLabels = @(@{ Label = 'Dependent Picklist Rules'; LanguageCode = 1033 })
  }
  Description                = @{
    LocalizedLabels = @(@{ Label = 'Mapping rules for Salesforce-style dependent picklists'; LanguageCode = 1033 })
  }
  HasActivities              = $false
  HasNotes                   = $false
  IsActivity                 = $false
  OwnershipType              = 'UserOwned'
  PrimaryNameAttribute       = 'mau_name'
  Attributes                 = @(
    @{
      '@odata.type'  = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
      SchemaName     = 'mau_Name'
      LogicalName    = 'mau_name'
      RequiredLevel  = @{ Value = 'ApplicationRequired' }
      MaxLength      = 200
      FormatName     = @{ Value = 'Text' }
      IsPrimaryName  = $true
      DisplayName    = @{ LocalizedLabels = @(@{ Label = 'Name'; LanguageCode = 1033 }) }
      Description    = @{ LocalizedLabels = @(@{ Label = 'Auto-generated rule name'; LanguageCode = 1033 }) }
    }
  )
}

$created = Invoke-Dv -Method POST -Path "/api/data/v9.2/EntityDefinitions" -Body $entityBody -ExtraHeaders @{ 'MSCRM.SolutionUniqueName' = $solutionUniqueName }
Write-Host "Table created" -ForegroundColor Green
