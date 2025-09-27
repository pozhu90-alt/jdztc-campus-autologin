param(
    [string]$OutputName = 'CampusNet_packed.exe',
    [switch]$Obfuscate,
    [switch]$Blank
)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root   = Split-Path $PSScriptRoot -Parent
$build  = $PSScriptRoot
$dist   = Join-Path $root 'dist'
if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist | Out-Null }

# 1) 准备嵌入文件映射（目标→源）
$appData = '%APPDATA%\\CampusNet'
$embed = @{}
$embed["$appData\\gui\\config_gui.ps1"]              = (Join-Path $root 'dist\config_gui.ps1')
$embed["$appData\\scripts\\start_auth.ps1"]          = (Join-Path $root 'scripts\start_auth.ps1')
$embed["$appData\\scripts\\modules\\wifi.psm1"]     = (Join-Path $root 'scripts\modules\wifi.psm1')
$embed["$appData\\scripts\\modules\\netdetect.psm1"] = (Join-Path $root 'scripts\modules\netdetect.psm1')
$embed["$appData\\scripts\\modules\\security.psm1"]  = (Join-Path $root 'scripts\modules\security.psm1')
$embed["$appData\\scripts\\modules\\cdp.psm1"]       = (Join-Path $root 'scripts\modules\cdp.psm1')
$embed["$appData\\portal_autofill\\autofill_core.js"] = (Join-Path $root 'portal_autofill\autofill_core.js')
$embed["$appData\\tasks\\install_autostart.ps1"]      = (Join-Path $root 'tasks\install_autostart.ps1')

# 选择嵌入的默认配置：Blank 模式使用 build\config.blank.json，否则使用根目录 config.json
$cfgSrc = (Join-Path $root 'config.json')
if ($Blank) {
    $blankCfg = Join-Path $build 'config.blank.json'
    if (Test-Path $blankCfg) { $cfgSrc = $blankCfg }
}
$embed["$appData\\config.default.json"] = $cfgSrc

# 非 Blank 模式下才附带最近一次 Wi‑Fi 成功状态
if (-not $Blank) {
    if (Test-Path (Join-Path $root 'wifi_state.json')) { $embed["$appData\\wifi_state.json"] = (Join-Path $root 'wifi_state.json') }
}

# 2) 载入 ps2exe 并编译 launcher.ps1 为独立 EXE（无控制台）
. (Join-Path $build 'ps2exe.ps1')
$launcher = Join-Path $build 'launcher.ps1'
if (-not (Test-Path $launcher)) { throw "launcher.ps1 not found. Ensure build/launcher.ps1 exists" }

$outFile = Join-Path $dist $OutputName
try {
    Invoke-ps2exe -inputFile $launcher -outputFile $outFile -noConsole -STA -title 'CampusNet' -product 'CampusNet' -company 'Campus' -description 'Auto WiFi + Portal' -embedFiles $embed -supportOS -winFormsDPIAware | Out-Null
    Write-Host ("Built: " + $outFile) -ForegroundColor Green
} catch {
    Write-Host ("ps2exe build failed: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

# 3) 可选：ConfuserEx 混淆
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


