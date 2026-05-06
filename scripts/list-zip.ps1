Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [IO.Compression.ZipFile]::OpenRead((Resolve-Path 'dist\DependentPicklists.zip'))
$z.Entries | ForEach-Object { Write-Host $_.FullName }
$z.Dispose()
