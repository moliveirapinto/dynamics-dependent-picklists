. "$PSScriptRoot\dv.ps1"
$attrs = (Invoke-Dv -Method GET -Path "/api/data/v9.2/EntityDefinitions(LogicalName='incident')/Attributes/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=LogicalName,DisplayName&`$expand=OptionSet(`$select=Options)").value
foreach ($a in $attrs) {
  $label = $a.DisplayName.UserLocalizedLabel.Label
  Write-Host "$($a.LogicalName) ($label)" -ForegroundColor Cyan
  foreach ($o in $a.OptionSet.Options) {
    Write-Host ("    {0,5}  {1}" -f $o.Value, $o.Label.UserLocalizedLabel.Label)
  }
}
