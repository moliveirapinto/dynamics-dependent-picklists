$dir = Get-ChildItem $env:TEMP -Directory -Filter "DependentPicklists_unpack_*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host "Dir: $($dir.FullName)"
$cust = Get-Content -Raw (Join-Path $dir.FullName 'customizations.xml')
Write-Host "File size: $($cust.Length)"
$idx = $cust.IndexOf('4a63c8d1-6c1e-48ec-9db4-3e6c7155334c')
Write-Host "Index: $idx"
if ($idx -ge 0) {
  $start = [Math]::Max(0, $idx - 50)
  $len = [Math]::Min(3000, $cust.Length - $start)
  Write-Host $cust.Substring($start, $len)
}
