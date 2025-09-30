param()

# 检查管理员权限，若无则自动提权
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    try {
        $self = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
        $launchArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File', "`"$self`"")
        Start-Process -FilePath 'powershell.exe' -ArgumentList $launchArgs -Verb RunAs | Out-Null
        exit
    } catch {
        # 需要管理员权限提示（使用Console避免WPF未加载问题）
        Write-Host "Error: This program requires Administrator privileges." -ForegroundColor Red
        Write-Host "Please right-click and select 'Run as Administrator'." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit
    }
}

# 确保以 STA 线程运行（WPF 需求）；若不是，则以 -STA 自重启本脚本
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    try {
        $self = (Get-Item -LiteralPath $PSCommandPath).FullName
    } catch {
        $self = $MyInvocation.MyCommand.Path
    }
    $launchArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File', $self)
    Start-Process -FilePath 'powershell.exe' -ArgumentList $launchArgs -Verb RunAs | Out-Null
    exit
}

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# Paths
$root = Split-Path $PSScriptRoot -Parent
$cfgPath = Join-Path $root 'config.json'
$modulesPath = Join-Path $root 'scripts\modules'
$startScript = Join-Path $root 'scripts\start_auth.ps1'

try { Import-Module (Join-Path $modulesPath 'security.psm1') -Force -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction SilentlyContinue } catch {}
try { Import-Module (Join-Path $modulesPath 'wifi.psm1') -Force -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction SilentlyContinue } catch {}

function Show-Info([string]$msg) { [void][System.Windows.MessageBox]::Show($msg) }
function Show-Error([string]$msg) { [void][System.Windows.MessageBox]::Show($msg) }

Add-Type -AssemblyName PresentationFramework | Out-Null
Add-Type -AssemblyName PresentationCore | Out-Null
Add-Type -AssemblyName WindowsBase | Out-Null
try { Add-Type -AssemblyName System.Windows.Forms | Out-Null } catch {}

# Helper to compose Chinese text safely from Unicode code points (avoids file-encoding问题)
function CS { param([int[]]$u) return (-join ($u | ForEach-Object { [char]$_ })) }

# Build Window in code (avoid XAML encoding issues)
$window = New-Object System.Windows.Window
$window.Title = (CS @(0x6821,0x56ED,0x7F51,0x4E00,0x952E,0x5DE5,0x5177,0x0020,0x002D,0x0020,0x914D,0x7F6E))
$window.Width = 560
$window.Height = 580
$window.WindowStartupLocation = 'CenterScreen'
$window.FontFamily = 'Microsoft YaHei UI'
$window.FontSize = 14
[void]($window.Resources)

$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = '16'

# rows - 精简为9行（删除Windows密码行）
foreach ($h in @('Auto','Auto','Auto','Auto','Auto','Auto','Auto','*','Auto')) {
    $rd = New-Object System.Windows.Controls.RowDefinition
    $rd.Height = $h
    [void]$grid.RowDefinitions.Add($rd)
}
# cols
$cd0 = New-Object System.Windows.Controls.ColumnDefinition; $cd0.Width='140'; [void]$grid.ColumnDefinitions.Add($cd0)
$cd1 = New-Object System.Windows.Controls.ColumnDefinition; $cd1.Width='*';   [void]$grid.ColumnDefinitions.Add($cd1)

# label/text user
$tbUserL = New-Object System.Windows.Controls.TextBlock; $tbUserL.Text=(CS @(0x5B66,0x5DE5,0x53F7,0xFF1A)); $tbUserL.VerticalAlignment='Center'; $tbUserL.Margin='0,4,8,4'
[System.Windows.Controls.Grid]::SetRow($tbUserL,0); [System.Windows.Controls.Grid]::SetColumn($tbUserL,0); [void]$grid.Children.Add($tbUserL)
$TxtUser = New-Object System.Windows.Controls.TextBox; $TxtUser.Height=28; $TxtUser.Margin='0,4,0,4'
[System.Windows.Controls.Grid]::SetRow($TxtUser,0); [System.Windows.Controls.Grid]::SetColumn($TxtUser,1); [void]$grid.Children.Add($TxtUser)

# label/password
$tbPwdL = New-Object System.Windows.Controls.TextBlock; $tbPwdL.Text=(CS @(0x6570,0x5B57,0x5316,0x0028,0x4E91,0x9676,0x0029,0x5BC6,0x7801,0xFF1A)); $tbPwdL.VerticalAlignment='Center'; $tbPwdL.Margin='0,4,8,4'
[System.Windows.Controls.Grid]::SetRow($tbPwdL,1); [System.Windows.Controls.Grid]::SetColumn($tbPwdL,0); [void]$grid.Children.Add($tbPwdL)
$PwdBox = New-Object System.Windows.Controls.PasswordBox; $PwdBox.Height=28; $PwdBox.Margin='0,4,0,4'
[System.Windows.Controls.Grid]::SetRow($PwdBox,1); [System.Windows.Controls.Grid]::SetColumn($PwdBox,1); [void]$grid.Children.Add($PwdBox)

# 登录延迟设置（登录启动模式，无需Windows密码）
$tbDelayL = New-Object System.Windows.Controls.TextBlock; $tbDelayL.Text=(CS @(0x767B,0x5F55,0x5EF6,0x8FDF,0xFF1A)); $tbDelayL.VerticalAlignment='Center'; $tbDelayL.Margin='0,4,8,4'
[System.Windows.Controls.Grid]::SetRow($tbDelayL,2); [System.Windows.Controls.Grid]::SetColumn($tbDelayL,0); [void]$grid.Children.Add($tbDelayL)
$spDelay = New-Object System.Windows.Controls.StackPanel; $spDelay.Orientation='Horizontal'; $spDelay.Margin='0,4,0,4'
$SldDelay = New-Object System.Windows.Controls.Slider; $SldDelay.Minimum=0.1; $SldDelay.Maximum=3; $SldDelay.Value=1; $SldDelay.Width=200; $SldDelay.TickFrequency=0.1; $SldDelay.IsSnapToTickEnabled=$false
$LblDelay = New-Object System.Windows.Controls.TextBlock; $LblDelay.Text='1.0' + (CS @(0x79D2)); $LblDelay.Margin='12,0,0,0'; $LblDelay.VerticalAlignment='Center'
$SldDelay.add_ValueChanged({ try { $LblDelay.Text = ([Math]::Round($SldDelay.Value, 1)).ToString('0.0') + (CS @(0x79D2)) } catch {} })
[void]$spDelay.Children.Add($SldDelay); [void]$spDelay.Children.Add($LblDelay)
[System.Windows.Controls.Grid]::SetRow($spDelay,2); [System.Windows.Controls.Grid]::SetColumn($spDelay,1); [void]$grid.Children.Add($spDelay)

# ISP combobox
$tbIspL = New-Object System.Windows.Controls.TextBlock; $tbIspL.Text=(CS @(0x8FD0,0x8425,0x5546,0xFF1A)); $tbIspL.VerticalAlignment='Center'; $tbIspL.Margin='0,4,8,4'
[System.Windows.Controls.Grid]::SetRow($tbIspL,3); [System.Windows.Controls.Grid]::SetColumn($tbIspL,0); [void]$grid.Children.Add($tbIspL)
$CmbISP = New-Object System.Windows.Controls.ComboBox; $CmbISP.Height=28; $CmbISP.Margin='0,4,0,4'
foreach($t in @(
    (CS @(0x4E2D,0x56FD,0x8054,0x901A)),
    (CS @(0x4E2D,0x56FD,0x7535,0x4FE1)),
    (CS @(0x4E2D,0x56FD,0x79FB,0x52A8)),
    (CS @(0x65E0))
)){
    $item=New-Object System.Windows.Controls.ComboBoxItem; $item.Content=$t; [void]$CmbISP.Items.Add($item)
}
[System.Windows.Controls.Grid]::SetRow($CmbISP,3); [System.Windows.Controls.Grid]::SetColumn($CmbISP,1); [void]$grid.Children.Add($CmbISP)

# Wi‑Fi selection
$tbWifiL = New-Object System.Windows.Controls.TextBlock; $tbWifiL.Text=(CS @(0x0057,0x0069,0x002D,0x0046,0x0069,0x0020,0x9009,0x62E9,0xFF1A)); $tbWifiL.VerticalAlignment='Center'; $tbWifiL.Margin='0,4,8,4'
[System.Windows.Controls.Grid]::SetRow($tbWifiL,4); [System.Windows.Controls.Grid]::SetColumn($tbWifiL,0); [void]$grid.Children.Add($tbWifiL)
$spWifi = New-Object System.Windows.Controls.StackPanel; $spWifi.Orientation='Horizontal'; $spWifi.Margin='0,4,0,4'
$RbAuto = New-Object System.Windows.Controls.RadioButton; $RbAuto.Content=(CS @(0x5B66,0x6821,0x7F51)); $RbAuto.IsChecked=$true; $RbAuto.Margin='0,0,16,0'
$RbJCI  = New-Object System.Windows.Controls.RadioButton; $RbJCI.Content=(CS @(0x6821,0x56ED,0x7F51,0x004A,0x0043,0x0049));
[void]$spWifi.Children.Add($RbAuto); [void]$spWifi.Children.Add($RbJCI)
[System.Windows.Controls.Grid]::SetRow($spWifi,4); [System.Windows.Controls.Grid]::SetColumn($spWifi,1); [void]$grid.Children.Add($spWifi)

# Signal slider
$tbSigL = New-Object System.Windows.Controls.TextBlock; $tbSigL.Text=(CS @(0x4F4E,0x4E8E,0x767E,0x5206,0x503C,0x4E0D,0x8FDE,0x63A5,0xFF1A)); $tbSigL.VerticalAlignment='Center'; $tbSigL.Margin='0,8,8,4'
[System.Windows.Controls.Grid]::SetRow($tbSigL,5); [System.Windows.Controls.Grid]::SetColumn($tbSigL,0); [void]$grid.Children.Add($tbSigL)
$spSig = New-Object System.Windows.Controls.StackPanel; $spSig.Orientation='Horizontal'; $spSig.Margin='0,8,0,4'
$SldSignal = New-Object System.Windows.Controls.Slider; $SldSignal.Minimum=10; $SldSignal.Maximum=80; $SldSignal.Value=30; $SldSignal.Width=240; $SldSignal.TickFrequency=5; $SldSignal.IsSnapToTickEnabled=$true
$LblSignal = New-Object System.Windows.Controls.TextBlock; $LblSignal.Text='30%'; $LblSignal.Margin='12,0,0,0'; $LblSignal.VerticalAlignment='Center'
$SldSignal.add_ValueChanged({ try { $LblSignal.Text = ([int]$SldSignal.Value).ToString() + '%' } catch {} })
[void]$spSig.Children.Add($SldSignal); [void]$spSig.Children.Add($LblSignal)
[System.Windows.Controls.Grid]::SetRow($spSig,5); [System.Windows.Controls.Grid]::SetColumn($spSig,1); [void]$grid.Children.Add($spSig)

# Browser combobox
$tbBrL = New-Object System.Windows.Controls.TextBlock; $tbBrL.Text=(CS @(0x6D4F,0x89C8,0x5668,0xFF1A)); $tbBrL.VerticalAlignment='Center'; $tbBrL.Margin='0,4,8,4'
[System.Windows.Controls.Grid]::SetRow($tbBrL,6); [System.Windows.Controls.Grid]::SetColumn($tbBrL,0); [void]$grid.Children.Add($tbBrL)
$CmbBrowser = New-Object System.Windows.Controls.ComboBox; $CmbBrowser.Height=28; $CmbBrowser.Margin='0,4,0,4'
foreach($t in @('edge','chrome')){ $item=New-Object System.Windows.Controls.ComboBoxItem; $item.Content=$t; [void]$CmbBrowser.Items.Add($item) }
[System.Windows.Controls.Grid]::SetRow($CmbBrowser,6); [System.Windows.Controls.Grid]::SetColumn($CmbBrowser,1); [void]$grid.Children.Add($CmbBrowser)

# 添加模式说明
$tbAutoInfo = New-Object System.Windows.Controls.TextBlock
$tbAutoInfo.Text=(CS @(0x767B,0x5F55,0x542F,0x52A8,0xFF1A,0x8F93,0x5165,0x5BC6,0x7801,0x540E,0x81EA,0x52A8,0x8FDE,0x63A5,0xFF0C,0x4E0D,0x53D7,0x5FEB,0x901F,0x542F,0x52A8,0x5F71,0x54CD,0x3002,0x5EF6,0x8FDF,0x8303,0x56F4,0xFF1A,0x0030,0x002E,0x0031,0x002D,0x0033,0x79D2,0xFF0C,0x63A8,0x8350,0x0031,0x79D2,0x3002))
$tbAutoInfo.TextWrapping='Wrap'; $tbAutoInfo.Margin='0,8,0,8'; $tbAutoInfo.FontSize=12; $tbAutoInfo.Foreground='DarkGreen'
[System.Windows.Controls.Grid]::SetRow($tbAutoInfo,7); [System.Windows.Controls.Grid]::SetColumnSpan($tbAutoInfo,2); [void]$grid.Children.Add($tbAutoInfo)

# Buttons
$spBtn = New-Object System.Windows.Controls.StackPanel; $spBtn.Orientation='Horizontal'; $spBtn.HorizontalAlignment='Right'
$BtnRemoveTask = New-Object System.Windows.Controls.Button; $BtnRemoveTask.Content=(CS @(0x5220,0x9664,0x4EFB,0x52A1)); $BtnRemoveTask.Width=96; $BtnRemoveTask.Margin='0,8,8,0'; $BtnRemoveTask.Background='#FFFFE0E0'; $BtnRemoveTask.Foreground='#FF8B0000'
$BtnSave = New-Object System.Windows.Controls.Button; $BtnSave.Content=(CS @(0x4FDD,0x5B58,0x914D,0x7F6E)); $BtnSave.Width=96; $BtnSave.Margin='0,8,8,0'
$BtnSaveRun = New-Object System.Windows.Controls.Button; $BtnSaveRun.Content=(CS @(0x4FDD,0x5B58,0x5E76,0x8FDE,0x63A5)); $BtnSaveRun.Width=120; $BtnSaveRun.Margin='0,8,8,0'
$BtnExit = New-Object System.Windows.Controls.Button; $BtnExit.Content=(CS @(0x9000,0x51FA)); $BtnExit.Width=72; $BtnExit.Margin='0,8,0,0'
[void]$spBtn.Children.Add($BtnRemoveTask); [void]$spBtn.Children.Add($BtnSave); [void]$spBtn.Children.Add($BtnSaveRun); [void]$spBtn.Children.Add($BtnExit)
[System.Windows.Controls.Grid]::SetRow($spBtn,8); [System.Windows.Controls.Grid]::SetColumnSpan($spBtn,2); [void]$grid.Children.Add($spBtn)

$window.Content = $grid

# 直接使用上面创建的控件变量（不再通过 FindName 查找）

# Stable install location for autostart persistence
$stableRoot = Join-Path $env:APPDATA 'CampusNet'

# 强制所有读写都使用稳定目录下的 config.json（避免用户从不同位置运行导致读取错误文件）
$cfgPath = Join-Path $stableRoot 'config.json'

# 若稳定目录或配置文件不存在，进行初始化（从程序根目录的 config.json 复制，或写入默认配置）
if (-not (Test-Path $stableRoot)) { New-Item -ItemType Directory -Path $stableRoot | Out-Null }
if (-not (Test-Path $cfgPath)) {
    $seedDefault = Join-Path $stableRoot 'config.default.json'
    $seed = if (Test-Path $seedDefault) { $seedDefault } else { Join-Path $root 'config.json' }
    if (Test-Path $seed) {
        Copy-Item -LiteralPath $seed -Destination $cfgPath -Force -ErrorAction SilentlyContinue
    } else {
        $defaultCfg = [ordered]@{
            username = ''
            credential_id = 'CampusPortalCredential'
            wifi_names = @('JCU','SXL*','LIB*','CAFE*','HALL*','JCI')
            portal_entry_url = 'http://172.29.0.2/a79.htm'
            portal_probe_url = 'http://www.gstatic.com/generate_204'
            isp = ''
            ssid_rules = @()
            test_url = 'http://www.baidu.com'
            browser = 'edge'
            headless = $false
            autostart_delay_sec = 10
            log_file = 'campus_network.log'
            min_signal_percent = 30
        }
        ($defaultCfg | ConvertTo-Json -Depth 50) | Out-File -FilePath $cfgPath -Encoding UTF8 -Force
    }
}

function Copy-ToStable {
    param([string]$SourceRoot,[string]$DestRoot)
    try {
        if (-not (Test-Path $DestRoot)) { New-Item -ItemType Directory -Path $DestRoot | Out-Null }
        foreach ($item in @('scripts','portal_autofill','config.json','README.md','wifi_state.json')) {
            $src = Join-Path $SourceRoot $item
            if (Test-Path $src) {
                $dst = Join-Path $DestRoot $item
                if ((Get-Item $src).PSIsContainer) {
                    Copy-Item $src -Destination $dst -Recurse -Force -ErrorAction SilentlyContinue
                } else {
                    $dstDir = Split-Path $dst -Parent
                    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir | Out-Null }
                    Copy-Item $src -Destination $dst -Force -ErrorAction SilentlyContinue
                }
            }
        }
        # copy secrets if exists
        $secSrc = Join-Path $SourceRoot 'secrets.json'
        if (Test-Path $secSrc) { Copy-Item $secSrc -Destination (Join-Path $DestRoot 'secrets.json') -Force -ErrorAction SilentlyContinue }
        return $true
    } catch { return $false }
}

# Load current config
$cfg = $null
try { $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $cfg = $null }
if ($cfg) {
    if ($cfg.username) { $TxtUser.Text = [string]$cfg.username }
    # ISP preset：修复显示逻辑
    try {
        $ispText = [string]$cfg.isp
        if ($ispText) {
            $idx = switch ($ispText.ToLower()) {
                'unicom' { 0; break }
                'telecom' { 1; break }
                'cmcc' { 2; break }
                default { 3 }
            }
            $CmbISP.SelectedIndex = $idx
        } else {
            $CmbISP.SelectedIndex = 3
        }
    } catch { $CmbISP.SelectedIndex = 3 }
    # Wi‑Fi mode by wifi_names：严格按 config.json 恢复（仅 ['JCI'] → JCI；否则学校网）
    $names = @()
    try { $names = @($cfg.wifi_names) } catch { $names = @() }
    # 若配置中不是"仅 JCI"，则将其作为学校网模式的自动列表；否则回退到默认列表
    $script:__wifiNamesAuto = @('JCU','SXL*','LIB*','CAFE*','HALL*','JCI')
    if ($names -and -not ($names.Count -eq 1 -and $names[0] -eq 'JCI')) { $script:__wifiNamesAuto = @($names) }
    if ($names.Count -eq 1 -and $names[0] -eq 'JCI') { $RbJCI.IsChecked = $true } else { $RbAuto.IsChecked = $true }
    # Signal threshold
    try {
        if ($null -ne $cfg.min_signal_percent -and '' -ne $cfg.min_signal_percent) { $SldSignal.Value = [double]$cfg.min_signal_percent } else { $SldSignal.Value = 30 }
    } catch { $SldSignal.Value = 30 }
    # Login delay
    try {
        if ($null -ne $cfg.autostart_delay_sec -and '' -ne $cfg.autostart_delay_sec) { 
            $delayVal = [double]$cfg.autostart_delay_sec
            # 兼容旧配置：8-12秒的值转换为1-3秒
            if ($delayVal -gt 3) { $delayVal = 1 }
            $SldDelay.Value = [Math]::Max(0.1, [Math]::Min(3, $delayVal))
        } else { 
            $SldDelay.Value = 1 
        }
    } catch { $SldDelay.Value = 1 }
    # Browser preset
    try {
        $br = [string]$cfg.browser
        if ($br -and $br.Trim().Length -gt 0) {
            switch -Regex ($br) {
                'chrome' { $CmbBrowser.SelectedIndex = 1; break }
                default { $CmbBrowser.SelectedIndex = 0 }
            }
        } else { $CmbBrowser.SelectedIndex = 0 }
    } catch { $CmbBrowser.SelectedIndex = 0 }
    
    # 密码占位：若已有保存的密码，不显示明文，仅显示遮盖字符
    try {
        if (-not (Get-Command Load-Secret -ErrorAction SilentlyContinue)) { Import-Module (Join-Path $modulesPath 'security.psm1') -Force }
        $p0 = $null
        $credId = if ($cfg.credential_id) { [string]$cfg.credential_id } else { 'CampusPortalCredential' }
        try { $p0 = Load-Secret -Id $credId } catch { $p0 = $null }
        if ($p0 -and ([string]$p0).Length -gt 0) { 
            # 创建与真实密码长度一致的占位符，提升用户体验
            $pwdLength = ([string]$p0).Length
            $script:__pwdPlaceholderText = ('*' * $pwdLength)
            $PwdBox.Password = $script:__pwdPlaceholderText
            $script:__pwdPlaceholderActive = $true 
            # 保存原始密码的哈希用于验证（避免保存明文）
            $script:__pwdOriginalHash = ([System.Security.Cryptography.SHA256]::Create()).ComputeHash([System.Text.Encoding]::UTF8.GetBytes([string]$p0))
        } else {
            # 如果没有保存的密码，确保密码框为空
            $PwdBox.Password = ''
            $script:__pwdPlaceholderActive = $false
            $script:__pwdPlaceholderText = $null
            $script:__pwdOriginalHash = $null
        }
    } catch {}
} else {
    # 如果没有配置文件，也尝试加载默认的密码
    try {
        if (-not (Get-Command Load-Secret -ErrorAction SilentlyContinue)) { Import-Module (Join-Path $modulesPath 'security.psm1') -Force }
        $p0 = Load-Secret -Id 'CampusPortalCredential'
        if ($p0 -and ([string]$p0).Length -gt 0) { 
            $pwdLength = ([string]$p0).Length
            $script:__pwdPlaceholderText = ('*' * $pwdLength)
            $PwdBox.Password = $script:__pwdPlaceholderText
            $script:__pwdPlaceholderActive = $true 
            $script:__pwdOriginalHash = ([System.Security.Cryptography.SHA256]::Create()).ComputeHash([System.Text.Encoding]::UTF8.GetBytes([string]$p0))
        }
    } catch {}
}

# 缓存密码占位符状态 - 增强状态保护
if ($null -eq $script:__pwdPlaceholderActive) { $script:__pwdPlaceholderActive = $false }
if ($null -eq $script:__pwdPlaceholderText) { $script:__pwdPlaceholderText = $null }
if ($null -eq $script:__pwdOriginalHash) { $script:__pwdOriginalHash = $null }

# 防止占位符状态被意外重置的保护变量
$script:__pwdPlaceholderInitialized = $script:__pwdPlaceholderActive

# Signal label update
$SldSignal.add_ValueChanged({ $LblSignal.Text = [string]([int]$SldSignal.Value) + '%' })

# 当用户修改密码时，若此前为占位，则失效占位标记，改为以用户输入为准
$PwdBox.Add_PasswordChanged({ 
    param($s,$e) 
    try { 
        if ($script:__pwdPlaceholderActive) {
            $currentPwd = [string]$PwdBox.Password
            # 检查是否不再是占位符
            if ($currentPwd -ne [string]$script:__pwdPlaceholderText) { 
                $script:__pwdPlaceholderActive = $false 
                # 清除哈希信息，表示用户已修改密码
                $script:__pwdOriginalHash = $null
            }
        }
    } catch {} 
})

# 当密码框获得焦点时，如果是占位符则清空，便于用户输入
$PwdBox.Add_GotFocus({ 
    param($s,$e) 
    try { 
        if ($script:__pwdPlaceholderActive -and ([string]$PwdBox.Password -eq [string]$script:__pwdPlaceholderText)) {
            $PwdBox.Password = ''
            $script:__pwdPlaceholderActive = $false
            $script:__pwdOriginalHash = $null
        }
    } catch {} 
})


function Get-ISPValue() {
    switch ($CmbISP.SelectedIndex) {
        0 { return 'unicom' }
        1 { return 'telecom' }
        2 { return 'cmcc' }
        default { return '' }
    }
}

function Get-BrowserValue() {
    switch ($CmbBrowser.SelectedIndex) {
        1 { return 'chrome' }
        default { return 'edge' }
    }
}

# 系统级密码存储函数（用于SYSTEM账号访问）
function Save-SystemSecret {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$PlainPassword
    )
    try {
        # 尝试保存到用户可访问的位置，而不是ProgramData
        $userSecretPath = Join-Path $env:APPDATA 'CampusNet\user_secrets.json'
        $userDir = Split-Path $userSecretPath -Parent
        if (-not (Test-Path $userDir)) {
            New-Item -ItemType Directory -Path $userDir -Force | Out-Null
        }

        # 使用简单的Base64编码存储
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($PlainPassword))

        $data = @{}
        if (Test-Path $userSecretPath) {
            try { $data = Get-Content $userSecretPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable } catch {}
        }
        $data[$Id] = $encoded
        ($data | ConvertTo-Json -Depth 10) | Out-File -FilePath $userSecretPath -Encoding UTF8 -Force
        return $true
    } catch { 
        # 如果仍然失败，尝试保存到临时目录
        try {
            $tempSecretPath = Join-Path $env:TEMP 'CampusNet_user_secrets.json'
            $data = @{}
            if (Test-Path $tempSecretPath) {
                try { $data = Get-Content $tempSecretPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable } catch {}
            }
            $data[$Id] = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($PlainPassword))
            ($data | ConvertTo-Json -Depth 10) | Out-File -FilePath $tempSecretPath -Encoding UTF8 -Force
            return $true
        } catch {
            return $false
        }
    }
}

function Save-All([bool]$andRun) {
    try {
        if (-not (Test-Path $cfgPath)) { 
            Show-Error ("配置文件未找到: " + $cfgPath)
            return
        }
        
        $obj = $null
        try {
            $obj = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Show-Error ("配置文件格式错误: " + $_.Exception.Message)
            return
        }
        
        if (-not $obj) { 
            Show-Error "配置文件内容无效"
            return
        }

        # 规范为 hashtable，避免 PSObject 索引异常
        $j = [ordered]@{}
        foreach ($p in $obj.PSObject.Properties) { $j[$p.Name] = $p.Value }

        # Username
        $j['username'] = [string]$TxtUser.Text

        # Wi‑Fi names：按当前选择回写（学校网→恢复自动列表；JCI→仅 JCI）
        if ($RbJCI.IsChecked -eq $true) { 
            $j['wifi_names'] = @('JCI') 
        } elseif ($RbAuto.IsChecked -eq $true) { 
            if ($script:__wifiNamesAuto) { 
                # 确保是字符串数组
                $j['wifi_names'] = @($script:__wifiNamesAuto | ForEach-Object { [string]$_ })
            } else {
                $j['wifi_names'] = @('JCU','SXL*','LIB*','CAFE*','HALL*','JCI')
            }
        }
        # ISP and signal threshold
        $j['isp'] = Get-ISPValue
        $j['min_signal_percent'] = [int]$SldSignal.Value
        # Sync JCI rule ISP with current selection to avoid stale overrides during connect
        try {
            $rules = @()
            if ($j.Contains('ssid_rules') -and $j['ssid_rules']) { 
                # 转换为标准哈希表数组，避免PSCustomObject序列化问题
                foreach ($rule in $j['ssid_rules']) {
                    $rules += @{
                        pattern = [string]$rule.pattern
                        isp = [string]$rule.isp
                    }
                }
            }
            
            $found = $false
            for ($ri = 0; $ri -lt $rules.Count; $ri++) {
                if ($rules[$ri].pattern -eq 'JCI') { 
                    $rules[$ri].isp = $j['isp']
                    $found = $true
                    break 
                }
            }
            if (-not $found) { 
                $rules += @{ pattern='JCI'; isp=$j['isp'] }
            }
            $j['ssid_rules'] = $rules
        } catch {
            # 如果处理失败，设置默认规则
            $j['ssid_rules'] = @(@{ pattern='JCI'; isp=$j['isp'] })
        }

        # Browser
        $j['browser'] = Get-BrowserValue
        # 总是启用headless模式
        $j['headless'] = $true
        
        # 获取用户设置的延迟时间（支持小数）
        $userDelay = [Math]::Round([double]$SldDelay.Value, 1)
        $j['autostart_delay_sec'] = $userDelay
        if (-not $j.Contains('test_url') -or -not $j['test_url']) { $j['test_url'] = 'http://www.baidu.com' }
        if (-not $j.Contains('log_file') -or -not $j['log_file']) { $j['log_file'] = 'campus_network.log' }
        if (-not $j.Contains('portal_entry_url') -or -not $j['portal_entry_url']) { $j['portal_entry_url'] = 'http://172.29.0.2/a79.htm' }
        if (-not $j.Contains('portal_probe_url') -or -not $j['portal_probe_url']) { $j['portal_probe_url'] = 'http://www.gstatic.com/generate_204' }

        # Save config（写入稳定目录，同时保持根目录一致，避免用户看到两个不同配置）
        
        # 保存配置文件，包含错误处理
        try {
            $jsonContent = ($j | ConvertTo-Json -Depth 50)
            $jsonContent | Out-File -FilePath $cfgPath -Encoding UTF8 -Force
        } catch {
            Show-Error ("保存配置文件失败: " + $_.Exception.Message)
            return
        }
        
        try { 
            $jsonContent = ($j | ConvertTo-Json -Depth 50)
            $jsonContent | Out-File -FilePath (Join-Path $root 'config.json') -Encoding UTF8 -Force 
        } catch {}

        # 处理密码保存（门户密码）
        $userPwdPlain = [string]$PwdBox.Password
        $credId = [string]$j['credential_id']
        if (-not $credId -or $credId.Trim().Length -eq 0) { $credId = 'CampusPortalCredential' }
        
        # 更严格的占位符检测逻辑 - 多重验证防止误判
        $isPlaceholder = $false
        try {
            # 主要检查：占位符标记激活 AND 密码与占位符文本一致 AND 原始哈希存在
            $primaryCheck = ($script:__pwdPlaceholderActive -and 
                            ([string]$PwdBox.Password -eq [string]$script:__pwdPlaceholderText) -and
                            ($null -ne $script:__pwdOriginalHash))
            
            # 备用检查：如果主要标记失效，但密码明显是占位符字符
            $backupCheck = ((-not $script:__pwdPlaceholderActive) -and 
                           $script:__pwdPlaceholderInitialized -and
                           ([string]$PwdBox.Password -match '^[\*]{8,}$' -or [string]$PwdBox.Password -match '^[\u25cf]{8,}$'))
            
            # 额外检查：检查是否为常见占位符模式
            $patternCheck = (([string]$PwdBox.Password -match '^\*{3,}$' -or [string]$PwdBox.Password -match '^[\u25cf]{3,}$') -and 
                            ([string]$PwdBox.Password).Length -ge 8)
            
            if ($primaryCheck -or $backupCheck -or $patternCheck) { 
                $isPlaceholder = $true 
            }
        } catch {}


        # 密码保存逻辑 - 增强占位符检测
        $shouldSavePassword = $false
        $realPassword = $null
        
        # 多重检查防止占位符被当作真实密码
        if ($isPlaceholder) {
            # 如果是占位符，从已保存的密码中获取真实密码
            try {
                if (-not (Get-Command Load-Secret -ErrorAction SilentlyContinue)) { Import-Module (Join-Path $modulesPath 'security.psm1') -Force }
                $realPassword = Load-Secret -Id $credId
                if ($realPassword -and ([string]$realPassword).Length -gt 0) {
                    $shouldSavePassword = $true  # 重新保存现有密码以确保一致性
                }
            } catch {}
        } else {
            # 不是占位符，检查是否为有效的新密码
            if ($userPwdPlain -and $userPwdPlain.Trim().Length -gt 0) {
                # 多重验证：确保不是各种形式的占位符
                $isActuallyPlaceholder = $false
                if ($script:__pwdPlaceholderText) {
                    $isActuallyPlaceholder = ($userPwdPlain -eq $script:__pwdPlaceholderText)
                }
                # 检查是否为纯星号占位符
                if (-not $isActuallyPlaceholder) {
                    $isActuallyPlaceholder = ($userPwdPlain -match '^\*{3,}$' -or $userPwdPlain -match '^[\u25cf]{3,}$')
                }
                
                if (-not $isActuallyPlaceholder) {
                    $realPassword = $userPwdPlain
                    $shouldSavePassword = $true
                }
            }
        }
        
        # 保存真实密码
        if ($shouldSavePassword -and $realPassword) {
            try {
                if (-not (Get-Command Save-Secret -ErrorAction SilentlyContinue)) { Import-Module (Join-Path $modulesPath 'security.psm1') -Force }
                
                # 使用DPAPI保存密码
                $sec = ConvertTo-SecureString -String $realPassword -AsPlainText -Force
                Save-Secret -Id $credId -Secret $sec | Out-Null
                
                # 同步到稳定目录
                $rootSecret = Join-Path $root 'secrets.json'
                if (Test-Path $rootSecret) { try { Copy-Item $rootSecret -Destination (Join-Path $stableRoot 'secrets.json') -Force -ErrorAction SilentlyContinue } catch {} }
            } catch { }
        }

        # 处理密码删除情况（用户清空密码框且不是占位符）
        if (-not $isPlaceholder -and (-not $shouldSavePassword)) {
            foreach ($secPath in @((Join-Path $root 'secrets.json'), (Join-Path $stableRoot 'secrets.json'))) {
                if (-not (Test-Path $secPath)) { continue }
                try {
                    $raw = Get-Content $secPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($raw) { $raw.PSObject.Properties.Remove($credId) | Out-Null; ($raw | ConvertTo-Json -Depth 20) | Out-File -FilePath $secPath -Encoding UTF8 -Force }
                } catch { }
            }
        }

        # 设置开机自动连接（所有用户都启用）
        # ensure files in stable root
        [void](Copy-ToStable -SourceRoot $root -DestRoot $stableRoot)
        # write updated config/secrets to stable as well
        try {
            ($j | ConvertTo-Json -Depth 50) | Out-File -FilePath (Join-Path $stableRoot 'config.json') -Encoding UTF8 -Force
        } catch {}
        $secSrc2 = Join-Path $root 'secrets.json'
        if (Test-Path $secSrc2) {
            try {
                Copy-Item $secSrc2 -Destination (Join-Path $stableRoot 'secrets.json') -Force -ErrorAction SilentlyContinue
            } catch {}
        }

        # remove existing task if any (to switch trigger/principal reliably)
        try {
            Unregister-ScheduledTask -TaskName 'CampusPortalAutoConnect' -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        } catch {}

        # register scheduled task based on user selected delay
        $delay = [int]$SldDelay.Value
        
        # 固定使用开机启动模式
        $useStartupMode = $true
        
        # 创建两个动作：先确保WLAN启动，再执行认证
        $authPath = Join-Path $stableRoot 'scripts\start_auth.ps1'
        
        # 主认证动作
        $argString = ('-WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $authPath)
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argString
        
        # 使用登录启动触发器（不受Windows快速启动影响）
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        # 使用用户设置的延迟时间（0.1-3秒）
        $loginDelay = [Math]::Round($delay, 1)
        # 转换为秒数字符串（支持小数）
        $delayStr = if ($loginDelay -eq [int]$loginDelay) { 
            "PT{0}S" -f [int]$loginDelay 
        } else { 
            "PT{0}S" -f $loginDelay 
        }
        $trigger.Delay = $delayStr
        # 显式启用触发器
        $trigger.Enabled = $true

        try {
            # 登录启动模式：使用Principal方式（无需密码）
            $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
            Register-ScheduledTask -TaskName 'CampusPortalAutoConnect' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
            Show-Info ((CS @(0x2705,0x0020,0x767B,0x5F55,0x542F,0x52A8,0x4EFB,0x52A1,0x5DF2,0x521B,0x5EFA,0x0020,0x0028,0x5EF6,0x8FDF,0x007B,0x0030,0x007D,0x79D2,0x0029)) -f $loginDelay)
        } catch { 
            if ($_.Exception.Message -match "Access is denied|拒绝访问|0x80070005") {
                Show-Error ((CS @(0x274C,0x0020,0x6743,0x9650,0x4E0D,0x8DB3,0xFF1A,0x8BF7,0x4EE5,0x7BA1,0x7406,0x5458,0x8EAB,0x4EFD,0x8FD0,0x884C,0x6B64,0x7A0B,0x5E8F)))
            } else {
                Show-Error ((CS @(0x274C,0x0020,0x4EFB,0x52A1,0x521B,0x5EFA,0x5931,0x8D25,0x003A,0x0020)) + $_.Exception.Message)
            }
            return
        }

        if ($andRun) {
            if (Test-Path $startScript) {
                $psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $startScript)
                Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -WindowStyle Hidden | Out-Null
                # 保存并连接：也显示保存成功提示
                try { Show-Info (CS @(0x5DF2,0x4FDD,0x5B58,0xFF0C,0x6B63,0x5728,0x8FDE,0x63A5)) } catch {}
            } else {
                Show-Error "start_auth.ps1 not found."
            }
        } else {
            Show-Info (CS @(0x914D,0x7F6E,0x5DF2,0x4FDD,0x5B58))
        }
    } catch {
        $msg3 = "Save failed: " + $_.Exception.Message
        Show-Error $msg3
    }
}

# Remove Task Button Handler
$BtnRemoveTask.Add_Click({
    try {
        # Check if task exists
        $task = Get-ScheduledTask -TaskName 'CampusPortalAutoConnect' -ErrorAction SilentlyContinue
        
        if (-not $task) {
            Show-Info (CS @(0x4EFB,0x52A1,0x8BA1,0x5212,0x4E0D,0x5B58,0x5728,0xFF0C,0x65E0,0x9700,0x5220,0x9664))
            return
        }
        
        # Confirm dialog
        $result = [System.Windows.MessageBox]::Show(
            (CS @(0x786E,0x8BA4,0x8981,0x5220,0x9664,0x5F00,0x673A,0x81EA,0x52A8,0x8FDE,0x63A5,0x4EFB,0x52A1,0xFF1F,0x000A,0x000A,0x5220,0x9664,0x540E,0xFF0C,0x7A0B,0x5E8F,0x5C06,0x4E0D,0x4F1A,0x5728,0x767B,0x5F55,0x65F6,0x81EA,0x52A8,0x8FDE,0x63A5,0x6821,0x56ED,0x7F51,0x3002,0x000A,0x5982,0x679C,0x4E0D,0x518D,0x4F7F,0x7528,0x672C,0x7A0B,0x5E8F,0xFF0C,0x8BF7,0x5220,0x9664,0x4EFB,0x52A1,0x540E,0x518D,0x5220,0x9664,0x0020,0x0065,0x0078,0x0065,0x0020,0x6587,0x4EF6,0x3002)),
            (CS @(0x786E,0x8BA4,0x5220,0x9664)),
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        
        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            # Remove scheduled task
            Unregister-ScheduledTask -TaskName 'CampusPortalAutoConnect' -Confirm:$false -ErrorAction Stop
            
            # Success message
            Show-Info (CS @(0x2705,0x0020,0x4EFB,0x52A1,0x8BA1,0x5212,0x5DF2,0x6210,0x529F,0x5220,0x9664,0xFF01,0x000A,0x000A,0x7A0B,0x5E8F,0x5C06,0x4E0D,0x4F1A,0x5728,0x767B,0x5F55,0x65F6,0x81EA,0x52A8,0x8FD0,0x884C,0x3002,0x000A,0x5982,0x679C,0x8981,0x5378,0x8F7D,0x7A0B,0x5E8F,0xFF0C,0x8BF7,0x624B,0x52A8,0x5220,0x9664,0x0020,0x0065,0x0078,0x0065,0x0020,0x6587,0x4EF6,0x3002))
        }
    } catch {
        $errMsg = (CS @(0x5220,0x9664,0x4EFB,0x52A1,0x5931,0x8D25,0xFF1A)) + $_.Exception.Message
        Show-Error $errMsg
    }
})

$BtnSave.Add_Click({ Save-All $false })
$BtnSaveRun.Add_Click({ Save-All $true })
$BtnExit.Add_Click({ $window.Close() })

try {
    if (-not [System.Windows.Application]::Current) {
        $app = New-Object System.Windows.Application
        $app.ShutdownMode = [System.Windows.ShutdownMode]::OnLastWindowClose
        $app.Run($window) | Out-Null
    } else {
        $window.ShowDialog() | Out-Null
    }
} catch {
    $errMsg = "GUI launch failed: " + $_.Exception.Message
    try { [System.Windows.MessageBox]::Show($errMsg) | Out-Null } catch { }
}
