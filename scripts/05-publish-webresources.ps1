. "$PSScriptRoot\dv.ps1"

# Publish specific web resources by id (faster than PublishAllXml)
$webresources = (Invoke-Dv -Method GET -Path "/api/data/v9.2/webresourceset?`$select=webresourceid,name&`$filter=name eq 'mau_DependentPicklistAdmin.html' or name eq 'mau_DependentPicklistRuntime.js'").value
$ids = $webresources | ForEach-Object { $_.webresourceid }
$xml = "<importexportxml><webresources>" +
       (($ids | ForEach-Object { "<webresource>$_</webresource>" }) -join "") +
       "</webresources></importexportxml>"
Write-Host "Publishing web resources: $($ids -join ', ')" -ForegroundColor Cyan
Invoke-Dv -Method POST -Path "/api/data/v9.2/PublishXml" -Body @{ ParameterXml = $xml } | Out-Null
Write-Host "Published." -ForegroundColor Green
