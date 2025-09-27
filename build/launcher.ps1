$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

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
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "$gui"
    exit $LASTEXITCODE
}

if (Test-Path $auth) {
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$auth"
    exit $LASTEXITCODE
}

Write-Host '未找到 GUI 或主脚本，请确认已正确嵌入并解压到 %APPDATA%\CampusNet' -ForegroundColor Yellow
exit 1


