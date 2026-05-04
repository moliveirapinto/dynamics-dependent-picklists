. "$PSScriptRoot\dv.ps1"
$forms = (Invoke-Dv -Method GET -Path "/api/data/v9.2/systemforms?`$select=formid,name,type,formactivationstate,objecttypecode&`$filter=objecttypecode eq 'incident' and type eq 2").value
$forms | Select-Object name, formid, formactivationstate | Format-Table -AutoSize
