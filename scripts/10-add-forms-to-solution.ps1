. "$PSScriptRoot\dv.ps1"

$solutionUniqueName = 'DependentPicklists'
$forms = @(
  '4a63c8d1-6c1e-48ec-9db4-3e6c7155334c',  # Case
  '915f6055-2e07-4276-ae08-2b96c8d02c57'   # Case for Interactive experience
)

foreach ($f in $forms) {
  $body = @{
    ComponentId = $f
    ComponentType = 60   # SystemForm
    SolutionUniqueName = $solutionUniqueName
    AddRequiredComponents = $false
    DoNotIncludeSubcomponents = $true
  }
  try {
    Invoke-Dv -Method POST -Path "/api/data/v9.2/AddSolutionComponent" -Body $body | Out-Null
    Write-Host "Added form $f to solution" -ForegroundColor Green
  } catch {
    Write-Host "Add failed (or already in): $f" -ForegroundColor Yellow
  }
}
