$dir = Get-ChildItem $env:TEMP -Directory -Filter "DependentPicklists_unpack_*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$cust = Get-Content -Raw (Join-Path $dir.FullName 'customizations.xml')
$idx = $cust.IndexOf('4a63c8d1-6c1e-48ec-9db4-3e6c7155334c')
$endIdx = $cust.IndexOf('</systemform>', $idx)
$slice = $cust.Substring($idx, $endIdx - $idx)
Write-Host "Slice length: $($slice.Length)"
Write-Host "Has events tag: $($slice.Contains('<events'))"
Write-Host "Has Handler: $($slice.Contains('Handler'))"
Write-Host "Has MauDependentPicklists: $($slice.Contains('MauDependentPicklists'))"
Write-Host "Last 1500 chars:"
Write-Host ($slice.Substring([Math]::Max(0, $slice.Length - 1500)))
