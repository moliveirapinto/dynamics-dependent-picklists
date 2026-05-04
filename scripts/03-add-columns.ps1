. "$PSScriptRoot\dv.ps1"

$solutionUniqueName = 'DependentPicklists'
$entityLogical = 'mau_dependentpicklistrule'
$entityPath = "/api/data/v9.2/EntityDefinitions(LogicalName='$entityLogical')/Attributes"

function Add-Attr {
  param([hashtable]$Attr, [string]$Label)
  $logical = $Attr.LogicalName
  try {
    $existing = Invoke-Dv -Method GET -Path "/api/data/v9.2/EntityDefinitions(LogicalName='$entityLogical')/Attributes(LogicalName='$logical')?`$select=LogicalName"
    Write-Host "  [skip] $logical already exists" -ForegroundColor Yellow
    return
  } catch { }
  Invoke-Dv -Method POST -Path $entityPath -Body $Attr -ExtraHeaders @{ 'MSCRM.SolutionUniqueName' = $solutionUniqueName } | Out-Null
  Write-Host "  [ok]   $logical ($Label)" -ForegroundColor Green
}

# Entity logical name (string)
Add-Attr -Label 'Entity Logical Name' -Attr @{
  '@odata.type'   = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
  SchemaName      = 'mau_EntityLogicalName'
  LogicalName     = 'mau_entitylogicalname'
  RequiredLevel   = @{ Value = 'ApplicationRequired' }
  MaxLength       = 100
  FormatName      = @{ Value = 'Text' }
  DisplayName     = @{ LocalizedLabels = @(@{ Label = 'Entity Logical Name'; LanguageCode = 1033 }) }
}

# Controlling field logical name
Add-Attr -Label 'Controlling Field' -Attr @{
  '@odata.type'   = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
  SchemaName      = 'mau_ControllingFieldLogicalName'
  LogicalName     = 'mau_controllingfieldlogicalname'
  RequiredLevel   = @{ Value = 'ApplicationRequired' }
  MaxLength       = 100
  FormatName      = @{ Value = 'Text' }
  DisplayName     = @{ LocalizedLabels = @(@{ Label = 'Controlling Field Logical Name'; LanguageCode = 1033 }) }
}

# Dependent field logical name
Add-Attr -Label 'Dependent Field' -Attr @{
  '@odata.type'   = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
  SchemaName      = 'mau_DependentFieldLogicalName'
  LogicalName     = 'mau_dependentfieldlogicalname'
  RequiredLevel   = @{ Value = 'ApplicationRequired' }
  MaxLength       = 100
  FormatName      = @{ Value = 'Text' }
  DisplayName     = @{ LocalizedLabels = @(@{ Label = 'Dependent Field Logical Name'; LanguageCode = 1033 }) }
}

# Controlling option value (int)
Add-Attr -Label 'Controlling Option Value' -Attr @{
  '@odata.type'   = 'Microsoft.Dynamics.CRM.IntegerAttributeMetadata'
  SchemaName      = 'mau_ControllingOptionValue'
  LogicalName     = 'mau_controllingoptionvalue'
  RequiredLevel   = @{ Value = 'ApplicationRequired' }
  MinValue        = -2147483648
  MaxValue        = 2147483647
  Format          = 'None'
  DisplayName     = @{ LocalizedLabels = @(@{ Label = 'Controlling Option Value'; LanguageCode = 1033 }) }
}

# Allowed dependent option values (memo, JSON array)
Add-Attr -Label 'Allowed Dependent Values (JSON)' -Attr @{
  '@odata.type'   = 'Microsoft.Dynamics.CRM.MemoAttributeMetadata'
  SchemaName      = 'mau_AllowedDependentOptionValues'
  LogicalName     = 'mau_alloweddependentoptionvalues'
  RequiredLevel   = @{ Value = 'ApplicationRequired' }
  MaxLength       = 4000
  Format          = 'TextArea'
  DisplayName     = @{ LocalizedLabels = @(@{ Label = 'Allowed Dependent Option Values (JSON)'; LanguageCode = 1033 }) }
}

# IsActive (bool)
Add-Attr -Label 'Is Active' -Attr @{
  '@odata.type'   = 'Microsoft.Dynamics.CRM.BooleanAttributeMetadata'
  SchemaName      = 'mau_IsActive'
  LogicalName     = 'mau_isactive'
  RequiredLevel   = @{ Value = 'None' }
  DefaultValue    = $true
  DisplayName     = @{ LocalizedLabels = @(@{ Label = 'Is Active'; LanguageCode = 1033 }) }
  OptionSet       = @{
    '@odata.type'  = 'Microsoft.Dynamics.CRM.BooleanOptionSetMetadata'
    TrueOption     = @{ Value = 1; Label = @{ LocalizedLabels = @(@{ Label = 'Yes'; LanguageCode = 1033 }) } }
    FalseOption    = @{ Value = 0; Label = @{ LocalizedLabels = @(@{ Label = 'No';  LanguageCode = 1033 }) } }
    OptionSetType  = 'Boolean'
  }
}

Write-Host "Done." -ForegroundColor Green
