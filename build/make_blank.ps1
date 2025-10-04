param(
  [string]$OutputName = 'CampusNet_blank.exe'
)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root   = Split-Path $PSScriptRoot -Parent
$build  = $PSScriptRoot
$dist   = Join-Path $root 'dist'
if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist | Out-Null }

$appData = '%APPDATA%\CampusNet'
$embed = @{}
$embed["$appData\\gui\\config_gui.ps1"]              = (Join-Path $root 'dist\config_gui.ps1')
$embed["$appData\\gui\\avatar.png"]                  = (Join-Path $root 'dist\avatar.png')
$embed["$appData\\gui\\minimize_avatar.png"]         = (Join-Path $root 'dist\minimize_avatar.png')
$embed["$appData\\gui\\maximize_avatar.png"]         = (Join-Path $root 'dist\maximize_avatar.png')
$embed["$appData\\gui\\close_avatar.png"]            = (Join-Path $root 'dist\close_avatar.png')
$embed["$appData\\scripts\\start_auth.ps1"]          = (Join-Path $root 'scripts\start_auth.ps1')
$embed["$appData\\scripts\\modules\\wifi.psm1"]     = (Join-Path $root 'scripts\modules\wifi.psm1')
$embed["$appData\\scripts\\modules\\netdetect.psm1"] = (Join-Path $root 'scripts\modules\netdetect.psm1')
$embed["$appData\\scripts\\modules\\security.psm1"]  = (Join-Path $root 'scripts\modules\security.psm1')
$embed["$appData\\scripts\\modules\\cdp.psm1"]       = (Join-Path $root 'scripts\modules\cdp.psm1')
$embed["$appData\\portal_autofill\\autofill_core.js"] = (Join-Path $root 'portal_autofill\autofill_core.js')
$embed["$appData\\tasks\\install_autostart.ps1"]      = (Join-Path $root 'tasks\install_autostart.ps1')
$embed["$appData\\config.default.json"]                 = (Join-Path $build 'config.blank.json')

. (Join-Path $build 'ps2exe.ps1')
$launcher = Join-Path $build 'launcher.ps1'
if (-not (Test-Path $launcher)) { throw "launcher.ps1 not found. Ensure build/launcher.ps1 exists" }

$outFile = Join-Path $dist $OutputName
Invoke-ps2exe -inputFile $launcher -outputFile $outFile -noConsole -STA -title 'CampusNet' -product 'CampusNet' -company 'Campus' -description 'Auto WiFi + Portal' -embedFiles $embed -supportOS -winFormsDPIAware | Out-Null
Write-Host ("Built blank: " + $outFile) -ForegroundColor Green


