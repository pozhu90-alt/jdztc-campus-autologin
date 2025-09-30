param(
    [ValidateSet('startup','logon')][string]$Mode='startup',
    [int]$DelaySec=8,
    [string]$User=(whoami),
    [string]$Password
)

$ErrorActionPreference = 'SilentlyContinue'

# User name is auto-detected via whoami in parameter default

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path $root -Parent
$stable = Join-Path $env:APPDATA 'CampusNet'
if (-not (Test-Path $stable)) { New-Item -ItemType Directory -Path $stable | Out-Null }

# sync files to stable location with proper handling of existing directories
foreach ($item in @('scripts','portal_autofill','config.json','wifi_state.json','secrets.json')) {
    $src = Join-Path $projectRoot $item
    if (Test-Path $src) {
        $dst = Join-Path $stable $item
        if ((Get-Item $src).PSIsContainer) {
            # For directories: remove existing target first to avoid nesting
            if (Test-Path $dst) { Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue }
            Copy-Item $src -Destination $stable -Recurse -Force -ErrorAction SilentlyContinue
        }
        else {
            # For files: ensure parent directory exists
            $dstDir = Split-Path $dst -Parent
            if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir | Out-Null }
            Copy-Item $src -Destination $dst -Force -ErrorAction SilentlyContinue
        }
    }
}

# force headless in stable config
try {
    $cfgPath = Join-Path $stable 'config.json'
    if (Test-Path $cfgPath) {
        $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $cfg.headless = $true
        ($cfg | ConvertTo-Json -Depth 50) | Out-File -FilePath $cfgPath -Encoding UTF8 -Force
    }
} catch {}

$startScript = Join-Path $stable 'scripts\start_auth.ps1'
if (-not (Test-Path $startScript)) { Write-Host 'start_auth.ps1 not found in stable directory' -ForegroundColor Red; exit 1 }

$taskName = 'CampusPortalAutoConnect'
$delay = $DelaySec

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ("-WindowStyle Hidden -ExecutionPolicy Bypass -File `"{0}`"" -f $startScript)
if ($Mode -eq 'startup') {
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = ("PT{0}S" -f $delay)
} else {
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $trigger.Delay = "PT1S"
}
$principal = New-ScheduledTaskPrincipal -UserId $User -RunLevel Highest

try {
    # remove existing to switch principal/trigger reliably
    try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null } catch {}

    if ($Mode -eq 'startup') {
        if (-not $Password) { 
            # 尝试从已保存的凭据中加载Windows密码
            try {
                Import-Module (Join-Path (Split-Path $root -Parent) 'scripts\modules\security.psm1') -Force -ErrorAction SilentlyContinue
                $winCredId = 'CampusWindowsCredential'
                $savedPassword = Load-Secret -Id $winCredId
                if ($savedPassword -and ([string]$savedPassword).Length -gt 0) {
                    $Password = [string]$savedPassword
                    Write-Host "✅ Using saved Windows password from credential store" -ForegroundColor Green
                } else {
                    $Password = Read-Host -AsSecureString 'Enter your Windows password (for task registration)'
                }
            } catch {
                $Password = Read-Host -AsSecureString 'Enter your Windows password (for task registration)'
            }
        }
        $pass = if ($Password -is [securestring]) { $Password } else { (ConvertTo-SecureString -AsPlainText $Password -Force) }
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -User $User -Password $pass -RunLevel Highest -Force | Out-Null
        Write-Host ("Task created: {0} (AtStartup, delay {1}s)" -f $taskName,$delay) -ForegroundColor Green
    } else {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
        Write-Host ("Task created: {0} (AtLogOn, delay 1s)" -f $taskName) -ForegroundColor Green
    }
} catch {
    Write-Host ("Failed to create scheduled task: {0}" -f $_.Exception.Message) -ForegroundColor Red
}