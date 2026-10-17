param([string]$PayloadRoot=(Join-Path $PSScriptRoot 'Payload'))
$ErrorActionPreference='Stop'
function Get-Imports([string]$Path) {
    $bytes=[IO.File]::ReadAllBytes($Path)
    $pe=[BitConverter]::ToInt32($bytes,0x3c)
    $sections=[BitConverter]::ToUInt16($bytes,$pe+6)
    $optional=$pe+24
    $magic=[BitConverter]::ToUInt16($bytes,$optional)
    $directory=if ($magic -eq 0x20b) { $optional+112 } else { $optional+96 }
    $table=$optional+[BitConverter]::ToUInt16($bytes,$pe+20)
    function Offset([uint32]$Rva) {
        for ($s=0;$s -lt $sections;$s++) {
            $entry=$table+$s*40
            $va=[BitConverter]::ToUInt32($bytes,$entry+12)
            $size=[Math]::Max([BitConverter]::ToUInt32($bytes,$entry+8),[BitConverter]::ToUInt32($bytes,$entry+16))
            if ($Rva -ge $va -and $Rva -lt ($va+$size)) { return [int]($Rva-$va+[BitConverter]::ToUInt32($bytes,$entry+20)) }
        }
        throw "Invalid RVA in $Path"
    }
    $rva=[BitConverter]::ToUInt32($bytes,$directory+8)
    if ($rva -eq 0) { return }
    $descriptor=Offset $rva
    while ([BitConverter]::ToUInt32($bytes,$descriptor+12) -ne 0) {
        $nameOffset=Offset ([BitConverter]::ToUInt32($bytes,$descriptor+12))
        $end=$nameOffset
        while ($bytes[$end] -ne 0) { $end++ }
        [Text.Encoding]::ASCII.GetString($bytes,$nameOffset,$end-$nameOffset)
        $descriptor+=20
    }
}
foreach ($exe in Get-ChildItem -LiteralPath $PayloadRoot -Recurse -Filter '*.exe' | Where-Object DirectoryName -notmatch '\\Redist$') {
    $imports=@(Get-Imports $exe.FullName)
    if ($imports | Where-Object { $_ -match '\.bpl$' }) { throw "$($exe.Name) requires Delphi runtime packages" }
    foreach ($dll in $imports) {
        if ($dll -notmatch '^api-ms-' -and -not (Test-Path -LiteralPath (Join-Path $exe.DirectoryName $dll)) -and
            -not (Test-Path -LiteralPath (Join-Path $env:WINDIR "System32\$dll")) -and
            -not (Test-Path -LiteralPath (Join-Path $env:WINDIR "SysWOW64\$dll"))) { throw "Missing import: $dll in $($exe.FullName)" }
    }
    Write-Output "$($exe.Directory.Name)\$($exe.Name): no BPL dependency; $($imports.Count) imports resolved on this host"
}
