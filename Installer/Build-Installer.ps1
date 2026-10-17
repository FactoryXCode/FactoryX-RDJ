[CmdletBinding()]
param(
    [string]$RadioDJRoot = 'D:\GitHub\FactoryX Radio DJ\FactoryX Radio DJ',
    [string]$MfPackRoot = 'D:\PROJECTS\MfPack',
    [string]$RDJBinary = '',
    [string]$ProBinary = '',
    [string]$RecorderBinary = '',
    [string]$ISCC = (Join-Path $PSScriptRoot 'Tools\InnoSetup\ISCC.exe')
)
$ErrorActionPreference='Stop'
$payload=Join-Path $PSScriptRoot 'Payload'
if (Test-Path -LiteralPath $payload) { throw 'Payload already exists. Move it aside before staging another release to avoid mixing builds.' }
if (-not $RDJBinary) { $RDJBinary=Join-Path $MfPackRoot 'Samples\MFRDJ Samples\MfRdjJ\Win32\Debug\MfRdjJ.exe' }
if (-not $ProBinary) { $ProBinary=Join-Path $MfPackRoot 'Samples\MFRDJ Samples\MfRdjPro\Win32\Debug\MfRdjJ.exe' }
if (-not $RecorderBinary) { $RecorderBinary=Join-Path $MfPackRoot 'Proxy Servers\FxRecord\Win64\Debug\FxRecord.exe' }
$manifest=[Collections.Generic.List[object]]::new()
function Stage([string]$Source,[string]$Relative) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { throw "Missing payload: $Source" }
    $dest=Join-Path $payload $Relative
    New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $dest
    $item=Get-Item -LiteralPath $Source
    $manifest.Add([pscustomobject]@{File=$Relative;Source=$Source;Bytes=$item.Length;ModifiedUTC=$item.LastWriteTimeUtc.ToString('o');SHA256=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash})
}
Stage $RDJBinary 'RDJ\MfRdjJ.exe'
Stage $ProBinary 'RDJPro\MfRdjJ.exe'
Stage $RecorderBinary 'FxRecord\FxRecord.exe'
Stage (Join-Path $MfPackRoot 'Proxy Servers\FxRecord\FxRecordAdmin\Win64\Debug\FxRecordAdmin.exe') 'FxRecordAdmin\FxRecordAdmin.exe'
foreach ($name in @('FxServe.exe','FxServeAdmin.exe')) { Stage (Join-Path $MfPackRoot "Proxy Servers\FxServe\Deploy\Portable\$name") "FxServe\$name" }
Stage (Join-Path $MfPackRoot 'Proxy Servers\FxServe\FxServe.ini') 'FxServe\FxServe.ini'
foreach ($name in @('FxRecord.ini','Install-FxRecord.cmd','Uninstall-FxRecord.cmd')) { Stage (Join-Path $MfPackRoot "Proxy Servers\FxRecord\$name") "FxRecord\$name" }
Stage (Join-Path $RadioDJRoot 'License.txt') 'License.txt'
Stage (Join-Path $RadioDJRoot 'RadioDJ\Redist\icecast_win64_2.5.0.exe') 'Redist\icecast_win64_2.5.0.exe'
foreach ($name in @('caddy.zip','Caddy_RDJ_Deploy.zip','Caddy_RDJ_PRO_Deploy.zip')) { Stage (Join-Path $RadioDJRoot "RadioDJ\Proxy Servers\Caddy\$name") "Caddy\$name" }
Stage (Join-Path $RadioDJRoot 'RadioDJ\MfRdjJ\Docs\RDJ-User-Manual.md') 'Docs\RDJ-User-Manual.md'
Stage (Join-Path $RadioDJRoot 'RadioDJ\MfRdjPro\RDJ-Pro-User-Manual.md') 'Docs\RDJ-Pro-User-Manual.md'
Stage (Join-Path $MfPackRoot 'Proxy Servers\FxServe\RDJ-Web-Server-Setup.md') 'Docs\RDJ-Web-Server-Setup.md'
Stage (Join-Path $MfPackRoot 'Proxy Servers\FxRecord\README.md') 'Docs\FxRecord-README.md'
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $payload 'BuildManifest.json') -Encoding UTF8
& (Join-Path $PSScriptRoot 'Check-Dependencies.ps1') -PayloadRoot $payload
if (-not (Test-Path -LiteralPath $ISCC)) { throw 'Install Inno Setup 6.7+ on the packaging machine and supply -ISCC. End users do not need it.' }
& $ISCC (Join-Path $PSScriptRoot 'FactoryXRadioDJ.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed: $LASTEXITCODE" }
Write-Output (Join-Path $PSScriptRoot 'Output\FactoryX-RadioDJ-4.0.1-Setup.exe')
