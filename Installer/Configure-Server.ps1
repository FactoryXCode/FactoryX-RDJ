[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InstallRoot,
    [ValidateSet('Local','LAN','WAN')][string]$NetworkMode = 'Local',
    [string]$PublicHostname = '',
    [switch]$ConfigureFxServe,
    [switch]$ConfigureFxRecord,
    [switch]$InitializeFxServe,
    [switch]$InitializeFxRecord,
    [switch]$InstallServices,
    [switch]$OpenFirewall
)
$ErrorActionPreference = 'Stop'
Start-Transcript -Path (Join-Path $PSScriptRoot 'Configure-Server.log') -Append | Out-Null
try {
    $root = [IO.Path]::GetFullPath($InstallRoot)
    if ($root.StartsWith('\\')) { throw 'Install services on a local drive, not a UNC share.' }
    if ($NetworkMode -eq 'WAN' -and $PublicHostname -notmatch '^(?=.{1,253}$)([a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$') {
        throw 'WAN mode requires a valid public DNS hostname.'
    }
    function Set-IniValue([string]$Path,[string]$Section,[string]$Key,[string]$Value) {
        $lines = [Collections.Generic.List[string]]::new()
        $lines.AddRange([string[]](Get-Content -LiteralPath $Path))
        $start = -1; $end = $lines.Count
        for ($i=0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -ieq "[$Section]") { $start=$i; break }
        }
        if ($start -lt 0) { $lines.Add(''); $lines.Add("[$Section]"); $lines.Add("$Key=$Value") }
        else {
            for ($i=$start+1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*\[') { $end=$i; break } }
            $found=$false
            for ($i=$start+1; $i -lt $end; $i++) {
                if ($lines[$i] -match ('^\s*'+[regex]::Escape($Key)+'\s*=')) { $lines[$i]="$Key=$Value"; $found=$true; break }
            }
            if (-not $found) { $lines.Insert($end,"$Key=$Value") }
        }
        [IO.File]::WriteAllLines($Path,$lines,[Text.UTF8Encoding]::new($false))
    }
    function Invoke-ServiceInstall([string]$Name) {
        $exe=Join-Path $root "$Name\$Name.exe"
        $ini=Join-Path $root "$Name\$Name.ini"
        if (Get-Service -Name $Name -ErrorAction SilentlyContinue) { throw "$Name already exists. Use its administrator to manage or repair the existing installation." }
        & $exe --install --config $ini
        if ($LASTEXITCODE -ne 0) { throw "$Name registration failed: $LASTEXITCODE" }
        Start-Service -Name $Name
    }
    if ($ConfigureFxServe) {
        $ini=Join-Path $root 'FxServe\FxServe.ini'
        if ($InitializeFxServe -and -not (Test-Path -LiteralPath "$ini.deployment-configured")) {
            Copy-Item -LiteralPath $ini -Destination "$ini.before-setup" -Force
            $bind = if ($NetworkMode -eq 'Local') { '127.0.0.1' } else { '0.0.0.0' }
            Set-IniValue $ini 'Server' 'BindAddress' $bind
            Set-IniValue $ini 'Wan' 'Enabled' ([string]($NetworkMode -eq 'WAN'))
            if ($NetworkMode -eq 'WAN') { Set-IniValue $ini 'Wan' 'HostName' $PublicHostname }
            Set-Content -LiteralPath "$ini.deployment-configured" -Value $NetworkMode
        } else { Write-Output 'Existing FxServe configuration preserved; change network settings in FxServe Admin.' }
        if ($OpenFirewall -and $NetworkMode -ne 'Local') {
            if (-not (Get-NetFirewallRule -Name 'FactoryX-RDJ-LAN' -ErrorAction SilentlyContinue)) {
                New-NetFirewallRule -Name 'FactoryX-RDJ-LAN' -DisplayName 'FactoryX RDJ LAN' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8080 -Profile Domain,Private | Out-Null
            }
            if ($NetworkMode -eq 'WAN' -and -not (Get-NetFirewallRule -Name 'FactoryX-RDJ-WAN' -ErrorAction SilentlyContinue)) {
                New-NetFirewallRule -Name 'FactoryX-RDJ-WAN' -DisplayName 'FactoryX RDJ WAN HTTPS and ACME' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80,443 -Profile Any | Out-Null
            }
        }
    }
    if ($ConfigureFxRecord) {
        $ini=Join-Path $root 'FxRecord\FxRecord.ini'
        if ($InitializeFxRecord -and -not (Test-Path -LiteralPath "$ini.deployment-configured")) {
            Copy-Item -LiteralPath $ini -Destination "$ini.before-setup" -Force
            Set-IniValue $ini 'Recorder' 'StreamPath' (Join-Path $root 'FxServe\www\Stream')
            Set-IniValue $ini 'Recorder' 'ArchivePath' (Join-Path $root 'FxRecord\ComplianceRecordings')
            Set-Content -LiteralPath "$ini.deployment-configured" -Value 'Configured'
        }
        New-Item -ItemType Directory -Path (Join-Path $root 'FxRecord\ComplianceRecordings') -Force | Out-Null
    }
    if ($InstallServices) {
        if ($ConfigureFxServe) { Invoke-ServiceInstall 'FxServe' }
        if ($ConfigureFxRecord) { Invoke-ServiceInstall 'FxRecord' }
    }
} catch { Write-Error $_; exit 1 }
finally { Stop-Transcript | Out-Null }
