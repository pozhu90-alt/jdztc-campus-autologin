$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
# Skip console encoding in noConsole mode
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$stable = Join-Path $env:APPDATA 'CampusNet'
$gui = Join-Path $stable 'gui\config_gui.ps1'
$auth = Join-Path $stable 'scripts\start_auth.ps1'

# Initialize user config on first run: copy default to active config if missing
$cfg = Join-Path $stable 'config.json'
$cfgDefault = Join-Path $stable 'config.default.json'
if (-not (Test-Path $cfg) -and (Test-Path $cfgDefault)) {
    try { Copy-Item -LiteralPath $cfgDefault -Destination $cfg -Force -ErrorAction SilentlyContinue } catch {}
}

if (Test-Path $gui) {
    # Set environment variable to tell GUI script to skip admin check (exe already has admin rights)
    $env:CAMPUSNET_SKIP_ADMIN_CHECK = '1'
    # Execute in the GUI script's directory to ensure $PSScriptRoot works correctly
    $guiDir = Split-Path $gui
    Set-Location $guiDir
    # Use PowerShell to execute with bypassed execution policy
    $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden', '-File', $gui)
    Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -NoNewWindow -Wait
    # Exit cleanly without displaying anything
    [System.Environment]::Exit(0)
}

if (Test-Path $auth) {
    Set-Location (Split-Path $auth)
    & $auth | Out-Null
    [System.Environment]::Exit(0)
}

# Only show error if nothing was found
[System.Windows.MessageBox]::Show('未找到 GUI 或主脚本，请确认已正确嵌入并解压', '错误', 'OK', 'Error') | Out-Null
exit 1


