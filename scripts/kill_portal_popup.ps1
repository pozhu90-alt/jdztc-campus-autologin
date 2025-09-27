param()

$ErrorActionPreference = 'SilentlyContinue'

function Is-PortalCommandLine([string]$cmd) {
    if (-not $cmd) { return $false }
    $patterns = @(
        'msftconnecttest',
        'msftncsi',
        'connecttest',
        'generate_204',
        '172.29.0.2',
        '/a79.htm',
        'wlanacip',
        'wlanname',
        'wlanacname'
    )
    foreach ($p in $patterns) { if ($cmd -match [regex]::Escape($p)) { return $true } }
    return $false
}

function Should-SkipKill([string]$cmd) {
    if (-not $cmd) { return $false }
    # do not touch our own automation (headless/devtools)
    if ($cmd -match '--headless' -or $cmd -match 'remote-debugging-port') { return $true }
    return $false
}

$deadline = (Get-Date).AddSeconds(30)
do {
    try {
        $procs = @(Get-CimInstance Win32_Process -Filter "Name='msedge.exe' OR Name='chrome.exe' OR Name='iexplore.exe'")
        foreach ($p in $procs) {
            $cmd = [string]$p.CommandLine
            if (Is-PortalCommandLine $cmd) {
                if (-not (Should-SkipKill $cmd)) {
                    try { Stop-Process -Id $p.ProcessId -Force } catch {}
                }
            }
        }
    } catch {}
    Start-Sleep -Milliseconds 400
} while ((Get-Date) -lt $deadline)


