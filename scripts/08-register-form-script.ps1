. "$PSScriptRoot\dv.ps1"

# Form IDs to update
$targetForms = @(
  '4a63c8d1-6c1e-48ec-9db4-3e6c7155334c',  # Case
  '915f6055-2e07-4276-ae08-2b96c8d02c57'   # Case for Interactive experience
)

$libraryName  = 'mau_DependentPicklistRuntime.js'
$functionName = 'MauDependentPicklists.onFormLoad'

function Update-FormXml([string]$formId) {
    Write-Host ""
    Write-Host "=== Form $formId ===" -ForegroundColor Cyan
    $form = Invoke-Dv -Method GET -Path "/api/data/v9.2/systemforms($formId)?`$select=name,formxml,formactivationstate"
    Write-Host "Name: $($form.name)" -ForegroundColor Cyan

    [xml]$xml = $form.formxml

    # 1) formLibraries
    $formLibsNode = $xml.SelectSingleNode("/form/formLibraries")
    if (-not $formLibsNode) {
        $formLibsNode = $xml.CreateElement("formLibraries")
        $xml.DocumentElement.PrependChild($formLibsNode) | Out-Null
    }
    $existingLib = $formLibsNode.SelectSingleNode("Library[@name='$libraryName']")
    if (-not $existingLib) {
        $lib = $xml.CreateElement("Library")
        $lib.SetAttribute("name", $libraryName)
        $lib.SetAttribute("libraryUniqueId", [Guid]::NewGuid().ToString("B"))
        $formLibsNode.AppendChild($lib) | Out-Null
        Write-Host "  + added Library $libraryName" -ForegroundColor Green
    } else {
        Write-Host "  = Library already present" -ForegroundColor Yellow
    }

    # 2) events / event[name=onload]
    $eventsNode = $xml.SelectSingleNode("/form/events")
    if (-not $eventsNode) {
        $eventsNode = $xml.CreateElement("events")
        $xml.DocumentElement.AppendChild($eventsNode) | Out-Null
    }
    $onloadEvent = $eventsNode.SelectSingleNode("event[@name='onload']")
    if (-not $onloadEvent) {
        $onloadEvent = $xml.CreateElement("event")
        $onloadEvent.SetAttribute("name", "onload")
        $onloadEvent.SetAttribute("application", "false")
        $onloadEvent.SetAttribute("active", "false")
        $handlersNode = $xml.CreateElement("Handlers")
        $onloadEvent.AppendChild($handlersNode) | Out-Null
        $eventsNode.AppendChild($onloadEvent) | Out-Null
    }
    $handlersNode = $onloadEvent.SelectSingleNode("Handlers")
    if (-not $handlersNode) {
        $handlersNode = $xml.CreateElement("Handlers")
        $onloadEvent.AppendChild($handlersNode) | Out-Null
    }
    $existingHandler = $handlersNode.SelectSingleNode("Handler[@functionName='$functionName' and @libraryName='$libraryName']")
    if (-not $existingHandler) {
        $h = $xml.CreateElement("Handler")
        $h.SetAttribute("functionName", $functionName)
        $h.SetAttribute("libraryName", $libraryName)
        $h.SetAttribute("handlerUniqueId", [Guid]::NewGuid().ToString("B"))
        $h.SetAttribute("enabled", "true")
        $h.SetAttribute("parameters", "")
        $h.SetAttribute("passExecutionContext", "true")
        $handlersNode.AppendChild($h) | Out-Null
        Write-Host "  + added OnLoad handler $functionName" -ForegroundColor Green
    } else {
        Write-Host "  = Handler already present" -ForegroundColor Yellow
    }

    $newXml = $xml.OuterXml
    Invoke-Dv -Method PATCH -Path "/api/data/v9.2/systemforms($formId)" -Body @{ formxml = $newXml } | Out-Null
    Write-Host "  saved formxml" -ForegroundColor Green
    return $formId
}

$updatedIds = @()
foreach ($f in $targetForms) {
    try { $updatedIds += (Update-FormXml -formId $f) } catch { Write-Host "Failed $f : $_" -ForegroundColor Red }
}

# Publish updated forms
if ($updatedIds.Count -gt 0) {
    $xml = "<importexportxml><systemforms>" +
           (($updatedIds | ForEach-Object { "<systemform>$_</systemform>" }) -join "") +
           "</systemforms></importexportxml>"
    Write-Host ""
    Write-Host "Publishing forms..." -ForegroundColor Cyan
    $ok=$false; for($i=0;$i -lt 12 -and -not $ok; $i++){
        try {
            Invoke-Dv -Method POST -Path "/api/data/v9.2/PublishXml" -Body @{ ParameterXml = $xml } | Out-Null
            Write-Host "Published." -ForegroundColor Green
            $ok=$true
        } catch {
            Write-Host "  publish busy, retrying in 10s..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
        }
    }
    if (-not $ok) { throw "Publish failed after retries." }
}
