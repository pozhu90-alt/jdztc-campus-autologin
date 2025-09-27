param(
    [string]$OutputName = '校园网一键工具.exe'
)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $root 'dist'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# Use ASCII-only staging under ProgramData to avoid Unicode path issues with IExpress
$work = Join-Path $env:ProgramData 'CampusNetBuild'
if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $work | Out-Null

# Flatten copy of the minimal runtime set
Copy-Item (Join-Path $root 'gui\config_gui.ps1') -Dest (Join-Path $work 'config_gui.ps1') -Force
Copy-Item (Join-Path $root 'scripts\start_auth.ps1') -Dest (Join-Path $work 'start_auth.ps1') -Force
Copy-Item (Join-Path $root 'scripts\modules\wifi.psm1') -Dest (Join-Path $work 'wifi.psm1') -Force
Copy-Item (Join-Path $root 'scripts\modules\netdetect.psm1') -Dest (Join-Path $work 'netdetect.psm1') -Force
Copy-Item (Join-Path $root 'scripts\modules\security.psm1') -Dest (Join-Path $work 'security.psm1') -Force
Copy-Item (Join-Path $root 'scripts\modules\cdp.psm1') -Dest (Join-Path $work 'cdp.psm1') -Force
Copy-Item (Join-Path $root 'portal_autofill\autofill_core.js') -Dest (Join-Path $work 'autofill_core.js') -Force
Copy-Item (Join-Path $root 'tasks\install_autostart.ps1') -Dest (Join-Path $work 'install_autostart.ps1') -Force
Copy-Item (Join-Path $root 'config.json') -Dest (Join-Path $work 'config.json') -Force
if (Test-Path (Join-Path $root 'README.md')) { Copy-Item (Join-Path $root 'README.md') -Dest (Join-Path $work 'README.md') -Force }
if (Test-Path (Join-Path $root 'wifi_state.json')) { Copy-Item (Join-Path $root 'wifi_state.json') -Dest (Join-Path $work 'wifi_state.json') -Force }
if (Test-Path (Join-Path $root 'campus_network.log')) { Copy-Item (Join-Path $root 'campus_network.log') -Dest (Join-Path $work 'campus_network.log') -Force }

# Create a tiny launcher to avoid CreateProcess quoting issues in IExpress
$runCmdPath = Join-Path $work 'run.cmd'
$runContent = @'
@echo off
setlocal
set SCRIPT_DIR=%~dp0
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%SCRIPT_DIR%config_gui.ps1"
'@
$runContent | Out-File -FilePath $runCmdPath -Encoding ASCII -Force

# Generate SED file
$sedPath = Join-Path $work 'package.sed'
$appCmd = 'run.cmd'
$postRunCmd = ''

$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3

[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=1
RebootMode=I
TargetName=$work\\$OutputName
FriendlyName=CampusNet
AppLaunched=$appCmd
PostInstallCmd=
AdminQuietInstCmd=
UserQuietInstCmd=
SourceFiles=SourceFiles

[Strings]
FILE0=config_gui.ps1
FILE1=start_auth.ps1
FILE2=wifi.psm1
FILE3=netdetect.psm1
FILE4=security.psm1
FILE5=cdp.psm1
FILE6=autofill_core.js
FILE7=config.json
FILE8=install_autostart.ps1
FILE9=wifi_state.json
FILE10=campus_network.log
FILE11=README.md
FILE12=run.cmd

[SourceFiles]
SourceFiles0=$work

[SourceFiles0]
%FILE0%=
%FILE1%=
%FILE2%=
%FILE3%=
%FILE4%=
%FILE5%=
%FILE6%=
%FILE7%=
%FILE8%=
%FILE9%=
%FILE10%=
%FILE11%=
%FILE12%=
"@

$sed | Out-File -FilePath $sedPath -Encoding ASCII -Force

# Invoke IExpress
$iexpress = Join-Path $env:SystemRoot 'System32\\iexpress.exe'
if (-not (Test-Path $iexpress)) {
    Write-Host 'iexpress.exe not found. Cannot build.' -ForegroundColor Red
    exit 1
}

Start-Process -FilePath $iexpress -ArgumentList "/N","$sedPath" -Wait

# Move output EXE to dist under project (may be Unicode)
$built = Join-Path $work $OutputName
if (Test-Path $built) {
    $destExe = Join-Path $outDir $OutputName
    Copy-Item $built -Destination $destExe -Force
    Write-Host "Built: $OutputName at $outDir" -ForegroundColor Green
} else {
    Write-Host "Build failed: output not found at $built" -ForegroundColor Red
}


