Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($z in 'dist\DependentPicklists.zip','dist\DependentPicklists_managed.zip') {
    $zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $z))
    $sol = $zip.Entries | Where-Object { $_.FullName -eq 'solution.xml' }
    $sr = New-Object IO.StreamReader($sol.Open())
    $x = $sr.ReadToEnd(); $sr.Close(); $zip.Dispose()
    $m = [regex]::Match($x,'<Version>([^<]+)</Version>')
    Write-Host ("{0} -> {1}" -f $z, $m.Groups[1].Value)
    # Also check admin html size
    $zip2 = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $z))
    $admin = $zip2.Entries | Where-Object { $_.FullName -like '*mau_DependentPicklistAdmin*' }
    Write-Host ("  admin html: {0} ({1} bytes)" -f $admin.FullName, $admin.Length)
    $zip2.Dispose()
}
