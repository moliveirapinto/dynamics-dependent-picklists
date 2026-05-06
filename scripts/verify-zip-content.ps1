Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [IO.Compression.ZipFile]::OpenRead((Resolve-Path 'dist\DependentPicklists_managed.zip'))
$e = $z.Entries | Where-Object { $_.FullName -like '*mau_DependentPicklistAdmin*' }
"Length=$($e.Length) Compressed=$($e.CompressedLength)"
$ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close()
$content = [Text.Encoding]::UTF8.GetString($ms.ToArray())
$z.Dispose()
"Bytes extracted: $($ms.Length)"
"Has v1.1.3.0: $($content -match 'v1\.1\.3\.0')"
"Has jsdelivr: $($content -match 'cdn\.jsdelivr\.net')"
"Has old api.github asset url: $($content -match 'releases/assets/')"
