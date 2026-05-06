$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$adminBytes = [IO.File]::ReadAllBytes((Resolve-Path 'webresources\mau_DependentPicklistAdmin.html'))
$newVersion = '1.1.2.0'

foreach ($zipName in 'DependentPicklists.zip','DependentPicklists_managed.zip') {
    $zipPath = (Resolve-Path "dist\$zipName").Path
    $tmp = "$env:TEMP\repack_$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $tmp | Out-Null

    # Collect entries (deduped by FullName, keeping first occurrence of each).
    $src = [IO.Compression.ZipFile]::OpenRead($zipPath)
    $entries = @{}
    $solXml = $null
    foreach ($e in $src.Entries) {
        if ($e.FullName -eq 'solution.xml') {
            if (-not $solXml) {
                $sr = New-Object IO.StreamReader($e.Open(), [Text.Encoding]::UTF8)
                $solXml = $sr.ReadToEnd(); $sr.Close()
            }
            continue
        }
        if (-not $entries.ContainsKey($e.FullName)) {
            $ms = New-Object IO.MemoryStream
            $stream = $e.Open(); $stream.CopyTo($ms); $stream.Close()
            $entries[$e.FullName] = $ms.ToArray()
        }
    }
    $src.Dispose()

    # Strip BOM if present and bump version
    if ($solXml.Length -gt 0 -and [int][char]$solXml[0] -eq 0xFEFF) { $solXml = $solXml.Substring(1) }
    $solXml = [regex]::Replace($solXml, '<Version>[^<]+</Version>', "<Version>$newVersion</Version>", 1)

    # Replace admin html
    $adminKey = ($entries.Keys | Where-Object { $_ -like '*mau_DependentPicklistAdmin*' })[0]
    if ($adminKey) { $entries[$adminKey] = $adminBytes }

    # Write fresh zip
    $newZip = "$tmp\new.zip"
    $z = [IO.Compression.ZipFile]::Open($newZip, 'Create')
    try {
        # solution.xml first (no BOM)
        $solBytes = ([Text.UTF8Encoding]::new($false)).GetBytes($solXml)
        $se = $z.CreateEntry('solution.xml')
        $os = $se.Open(); $os.Write($solBytes,0,$solBytes.Length); $os.Close()

        foreach ($k in $entries.Keys) {
            $ne = $z.CreateEntry($k)
            $os = $ne.Open(); $bytes = $entries[$k]; $os.Write($bytes,0,$bytes.Length); $os.Close()
        }
    } finally { $z.Dispose() }

    Copy-Item $newZip $zipPath -Force
    Remove-Item -Recurse -Force $tmp
    Write-Host "Repacked $zipName -> version $newVersion"
}
