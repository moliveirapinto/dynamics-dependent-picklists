# Dataverse Web API helper. Source-dot this file: . .\scripts\dv.ps1
$script:DvBaseUrl = 'https://mauriciomaster.crm.dynamics.com'
$script:DvTenant  = 'gbbrcg.onmicrosoft.com'

function Get-DvToken {
    az account get-access-token --resource $script:DvBaseUrl --tenant $script:DvTenant --query accessToken -o tsv
}

function Invoke-Dv {
    param(
        [Parameter(Mandatory)] [string] $Method,
        [Parameter(Mandatory)] [string] $Path,   # e.g. /api/data/v9.2/EntityDefinitions
        [object] $Body,
        [hashtable] $ExtraHeaders
    )
    $token = Get-DvToken
    $headers = @{
        'Authorization'    = "Bearer $token"
        'Accept'           = 'application/json'
        'OData-MaxVersion' = '4.0'
        'OData-Version'    = '4.0'
        'Prefer'           = 'return=representation'
    }
    if ($ExtraHeaders) { $ExtraHeaders.GetEnumerator() | ForEach-Object { $headers[$_.Key] = $_.Value } }

    $uri = "$($script:DvBaseUrl.TrimEnd('/'))$Path"
    $params = @{
        Method      = $Method
        Uri         = $uri
        Headers     = $headers
        ContentType = 'application/json; charset=utf-8'
    }
    if ($null -ne $Body) {
        $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 30 -Compress }
        $params['Body'] = [System.Text.Encoding]::UTF8.GetBytes($json)
    }
    try {
        Invoke-RestMethod @params
    } catch {
        $resp = $_.Exception.Response
        if ($resp) {
            try {
                $stream = $resp.GetResponseStream()
                $reader = New-Object IO.StreamReader($stream)
                $err = $reader.ReadToEnd()
                Write-Host "HTTP $($resp.StatusCode): $err" -ForegroundColor Red
            } catch {}
        }
        throw
    }
}
