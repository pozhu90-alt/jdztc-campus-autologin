param(
    [string]$OutputName = '小瓷连网.exe',
    [switch]$Obfuscate,
    [switch]$Blank,
    [switch]$Debug
)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root   = Split-Path $PSScriptRoot -Parent
$build  = $PSScriptRoot
$dist   = Join-Path $root 'dist'
if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist | Out-Null }

# 1) Prepare embedded files mapping (target -> source)
$appData = '%APPDATA%\\CampusNet'
$embed = @{}
$embed["$appData\\gui\\config_gui.ps1"]              = (Join-Path $root 'dist\config_gui_xiaoci.ps1')
$embed["$appData\\gui\\avatar.png"]                  = (Join-Path $root 'dist\avatar.png')
$embed["$appData\\gui\\minimize_avatar.png"]         = (Join-Path $root 'dist\minimize_avatar.png')
$embed["$appData\\gui\\maximize_avatar.png"]         = (Join-Path $root 'dist\maximize_avatar.png')
$embed["$appData\\gui\\close_avatar.png"]            = (Join-Path $root 'dist\close_avatar.png')
$embed["$appData\\scripts\\start_auth.ps1"]          = (Join-Path $root 'scripts\start_auth.ps1')
$embed["$appData\\scripts\\modules\\wifi.psm1"]     = (Join-Path $root 'scripts\modules\wifi.psm1')
$embed["$appData\\scripts\\modules\\netdetect.psm1"] = (Join-Path $root 'scripts\modules\netdetect.psm1')
$embed["$appData\\scripts\\modules\\security.psm1"]  = (Join-Path $root 'scripts\modules\security.psm1')
$embed["$appData\\scripts\\modules\\cdp.psm1"]       = (Join-Path $root 'scripts\modules\cdp.psm1')
$embed["$appData\\scripts\\modules\\stats.psm1"]     = (Join-Path $root 'scripts\modules\stats.psm1')
$embed["$appData\\scripts\\modules\\updater.psm1"]   = (Join-Path $root 'scripts\modules\updater.psm1')
$embed["$appData\\portal_autofill\\autofill_core.js"] = (Join-Path $root 'portal_autofill\autofill_core.js')
$embed["$appData\\tasks\\install_autostart.ps1"]      = (Join-Path $root 'tasks\install_autostart.ps1')

# Select embedded config: Blank mode uses build\config.blank.json, otherwise use root config.json
$cfgSrc = (Join-Path $root 'config.json')
if ($Blank) {
    $blankCfg = Join-Path $build 'config.blank.json'
    if (Test-Path $blankCfg) { $cfgSrc = $blankCfg }
}
$embed["$appData\\config.default.json"] = $cfgSrc

# Non-Blank mode includes last successful Wi-Fi state
if (-not $Blank) {
    $wifiState = Join-Path $root 'wifi_state.json'
    if (Test-Path $wifiState) { 
        $embed["$appData\\wifi_state.json"] = $wifiState 
    }
}

# 2) Load ps2exe and compile launcher.ps1 to standalone EXE (no console)
. (Join-Path $build 'ps2exe.ps1')
# Use debug launcher if requested
if ($Debug) {
    $launcher = Join-Path $build 'launcher_debug.ps1'
} else {
    $launcher = Join-Path $build 'launcher.ps1'
}
if (-not (Test-Path $launcher)) { throw "launcher not found: $launcher" }

$outFile = Join-Path $dist $OutputName

# Check for icon file
$iconFile = Join-Path $dist 'xi2o7-p1m0u-001.ico'
if (-not (Test-Path $iconFile)) {
    $iconFile = Join-Path $dist 'xiaoci_icon.ico'
}

try {
    if (Test-Path $iconFile) {
        Write-Host "Using icon: $iconFile" -ForegroundColor Cyan
        Invoke-ps2exe -inputFile $launcher -outputFile $outFile `
            -noConsole -requireAdmin -STA `
            -title 'XiaoCi Network' -product 'XiaoCi Network' -company 'Campus' `
            -description 'Campus Network Auto Connect Tool' `
            -iconFile $iconFile `
            -embedFiles $embed -supportOS -winFormsDPIAware -verbose
    } else {
        Write-Host "No custom icon found, building without icon..." -ForegroundColor Yellow
        Invoke-ps2exe -inputFile $launcher -outputFile $outFile `
            -noConsole -requireAdmin -STA `
            -title 'XiaoCi Network' -product 'XiaoCi Network' -company 'Campus' `
            -description 'Campus Network Auto Connect Tool' `
            -embedFiles $embed -supportOS -winFormsDPIAware -verbose
    }
    Write-Host ("Built: " + $outFile) -ForegroundColor Green
} catch {
    Write-Host ("ps2exe build failed: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

# 3) Optional: ConfuserEx obfuscation
if ($Obfuscate) {
    $confDir = Join-Path $build 'confuser'
    $cli = @(
        (Join-Path $confDir 'Confuser.CLI.exe'),
        (Join-Path $confDir 'ConfuserEx\Confuser.CLI.exe'),
        'Confuser.CLI.exe'
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $cli) {
        Write-Host "ConfuserEx CLI not found. Place Confuser.CLI.exe under build\\confuser\\ and re-run." -ForegroundColor Yellow
        Write-Host ("  " + (Join-Path $confDir 'Confuser.CLI.exe')) -ForegroundColor Yellow
        exit 0
    }

    $obfOut = Join-Path $dist 'obf'
    if (-not (Test-Path $obfOut)) { New-Item -ItemType Directory -Path $obfOut | Out-Null }
    $crproj = Join-Path $confDir 'CampusNet.crproj'
    $cr = @"
<?xml version="1.0" encoding="utf-8"?>
<project outputDir="$(Resolve-Path $obfOut)" baseDir="$(Resolve-Path $dist)" xmlns="http://confuser.codeplex.com">
  <rule pattern="true" inherit="false">
    <protection id="rename" />
    <protection id="ctrl flow" />
    <protection id="constants" />
    <protection id="resources" />
  </rule>
  <module path="$(Split-Path -Leaf $outFile)" />
</project>
"@
    $cr | Out-File -FilePath $crproj -Encoding UTF8 -Force

    & $cli $crproj | Write-Host
    if (Test-Path (Join-Path $obfOut (Split-Path -Leaf $outFile))) {
        Write-Host ("Obfuscated: " + (Join-Path $obfOut (Split-Path -Leaf $outFile))) -ForegroundColor Green
    } else {
        Write-Host "Obfuscation may have failed. Check ConfuserEx output." -ForegroundColor Yellow
    }
}