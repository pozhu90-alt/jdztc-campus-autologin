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
    # 给认证脚本更多保护时间 - 如果进程是最近30秒内创建的，可能是我们的认证进程
    return $false
}

# 延迟启动，给认证脚本足够的时间完成
Start-Sleep -Seconds 20

$deadline = (Get-Date).AddSeconds(30)
do {
    try {
        $procs = @(Get-CimInstance Win32_Process -Filter "Name='msedge.exe' OR Name='chrome.exe' OR Name='iexplore.exe'")
        foreach ($p in $procs) {
            $cmd = [string]$p.CommandLine
            if (Is-PortalCommandLine $cmd) {
                if (-not (Should-SkipKill $cmd)) {
                    # 额外检查：如果进程是最近30秒内创建的，可能是认证脚本，跳过
                    try {
                        $proc = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
                        if ($proc -and $proc.StartTime -and ((Get-Date) - $proc.StartTime).TotalSeconds -lt 30) {
                            continue  # 跳过最近创建的进程
                        }
                    } catch {}
                    try { Stop-Process -Id $p.ProcessId -Force } catch {}
                }
            }
        }
    } catch {}
    Start-Sleep -Milliseconds 400
} while ((Get-Date) -lt $deadline)


