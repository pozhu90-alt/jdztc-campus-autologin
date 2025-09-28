param()

# 确保以 STA 线程运行（WPF 需求）；若不是，则以 -STA 自重启本脚本
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    try {
        $self = (Get-Item -LiteralPath $PSCommandPath).FullName
    } catch {
        $self = $MyInvocation.MyCommand.Path
    }
    $launchArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File', $self)
    Start-Process -FilePath 'powershell.exe' -ArgumentList $launchArgs | Out-Null
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

# rows - 增加一行用于Windows密码
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

# Windows Password (新增) - 修改标签为"锁屏密码(无则不填)"
$tbWinPwdL = New-Object System.Windows.Controls.TextBlock; $tbWinPwdL.Text=(CS @(0x9501,0x5C4F,0x5BC6,0x7801,0x0028,0x65E0,0x5219,0x4E0D,0x586B,0x0029)); $tbWinPwdL.VerticalAlignment='Center'; $tbWinPwdL.Margin='0,4,8,4'
[System.Windows.Controls.Grid]::SetRow($tbWinPwdL,2); [System.Windows.Controls.Grid]::SetColumn($tbWinPwdL,0); [void]$grid.Children.Add($tbWinPwdL)
$WinPwdBox = New-Object System.Windows.Controls.PasswordBox; $WinPwdBox.Height=28; $WinPwdBox.Margin='0,4,0,4'
[System.Windows.Controls.Grid]::SetRow($WinPwdBox,2); [System.Windows.Controls.Grid]::SetColumn($WinPwdBox,1); [void]$grid.Children.Add($WinPwdBox)

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

# 移除了开机自动连接勾选框，添加提示信息
$tbAutoInfo = New-Object System.Windows.Controls.TextBlock
$tbAutoInfo.Text=(CS @(0x6CE8,0x610F,0xFF1A,0x672C,0x5DE5,0x5177,0x9ED8,0x8BA4,0x5F00,0x673A,0x81EA,0x52A8,0x8FDE,0x63A5,0xFF0C,0x82E5,0x65E0,0x0057,0x0069,0x006E,0x0064,0x006F,0x0077,0x0073,0x5BC6,0x7801,0x5219,0x4F7F,0x7528,0x7CFB,0x7EDF,0x8D26,0x53F7))
$tbAutoInfo.TextWrapping='Wrap'; $tbAutoInfo.Margin='0,8,0,8'; $tbAutoInfo.FontSize=12; $tbAutoInfo.Foreground='DarkBlue'
[System.Windows.Controls.Grid]::SetRow($tbAutoInfo,7); [System.Windows.Controls.Grid]::SetColumnSpan($tbAutoInfo,2); [void]$grid.Children.Add($tbAutoInfo)

# Buttons
$spBtn = New-Object System.Windows.Controls.StackPanel; $spBtn.Orientation='Horizontal'; $spBtn.HorizontalAlignment='Right'
$BtnSave = New-Object System.Windows.Controls.Button; $BtnSave.Content=(CS @(0x4FDD,0x5B58,0x914D,0x7F6E)); $BtnSave.Width=96; $BtnSave.Margin='0,8,8,0'
$BtnSaveRun = New-Object System.Windows.Controls.Button; $BtnSaveRun.Content=(CS @(0x4FDD,0x5B58,0x5E76,0x8FDE,0x63A5)); $BtnSaveRun.Width=120; $BtnSaveRun.Margin='0,8,8,0'
$BtnExit = New-Object System.Windows.Controls.Button; $BtnExit.Content=(CS @(0x9000,0x51FA)); $BtnExit.Width=72; $BtnExit.Margin='0,8,0,0'
[void]$spBtn.Children.Add($BtnSave); [void]$spBtn.Children.Add($BtnSaveRun); [void]$spBtn.Children.Add($BtnExit)
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
            autostart_delay_sec = 8
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
        try { $p0 = Load-Secret -Id ([string]$cfg.credential_id) } catch { $p0 = $null }
        if ($p0 -and ([string]$p0).Length -gt 0) { 
            # 创建与真实密码长度一致的占位符，提升用户体验
            $pwdLength = ([string]$p0).Length
            $script:__pwdPlaceholderText = ('*' * $pwdLength)
            $PwdBox.Password = $script:__pwdPlaceholderText
            $script:__pwdPlaceholderActive = $true 
            # 保存原始密码的哈希用于验证（避免保存明文）
            $script:__pwdOriginalHash = ([System.Security.Cryptography.SHA256]::Create()).ComputeHash([System.Text.Encoding]::UTF8.GetBytes([string]$p0))
        }
    } catch {}
    # Windows 密码占位：若上次保存过Windows密码，显示等长占位符
    try {
        if (-not (Get-Command Load-Secret -ErrorAction SilentlyContinue)) { Import-Module (Join-Path $modulesPath 'security.psm1') -Force }
        $winCredId = if ($cfg.windows_credential_id) { [string]$cfg.windows_credential_id } else { 'CampusWindowsCredential' }
        $wp0 = $null
        try { $wp0 = Load-Secret -Id $winCredId } catch { $wp0 = $null }
        if ($wp0 -and ([string]$wp0).Length -gt 0) {
            $wlen = ([string]$wp0).Length
            $script:__winPwdPlaceholderText = ('*' * $wlen)
            $WinPwdBox.Password = $script:__winPwdPlaceholderText
            $script:__winPwdPlaceholderActive = $true
        }
    } catch {}
}

# 缓存密码占位符状态
if ($null -eq $script:__pwdPlaceholderActive) { $script:__pwdPlaceholderActive = $false }
if ($null -eq $script:__pwdPlaceholderText) { $script:__pwdPlaceholderText = $null }
if ($null -eq $script:__pwdOriginalHash) { $script:__pwdOriginalHash = $null }
if ($null -eq $script:__winPwdPlaceholderActive) { $script:__winPwdPlaceholderActive = $false }
if ($null -eq $script:__winPwdPlaceholderText) { $script:__winPwdPlaceholderText = $null }

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

# Windows 密码占位：事件
$WinPwdBox.Add_PasswordChanged({ 
    param($s,$e) 
    try { 
        if ($script:__winPwdPlaceholderActive) {
            $currentPwd = [string]$WinPwdBox.Password
            if ($currentPwd -ne [string]$script:__winPwdPlaceholderText) { 
                $script:__winPwdPlaceholderActive = $false 
            }
        }
    } catch {} 
})

$WinPwdBox.Add_GotFocus({ 
    param($s,$e) 
    try { 
        if ($script:__winPwdPlaceholderActive -and ([string]$WinPwdBox.Password -eq [string]$script:__winPwdPlaceholderText)) {
            $WinPwdBox.Password = ''
            $script:__winPwdPlaceholderActive = $false
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
        $systemSecretPath = Join-Path $env:ProgramData 'CampusNet\system_secrets.json'
        $systemDir = Split-Path $systemSecretPath -Parent
        if (-not (Test-Path $systemDir)) {
            New-Item -ItemType Directory -Path $systemDir -Force | Out-Null
        }

        # 使用简单的Base64编码存储（不是真正的安全，但SYSTEM可以访问）
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($PlainPassword))

        $data = @{}
        if (Test-Path $systemSecretPath) {
            try { $data = Get-Content $systemSecretPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable } catch {}
        }
        $data[$Id] = $encoded
        ($data | ConvertTo-Json -Depth 10) | Out-File -FilePath $systemSecretPath -Encoding UTF8 -Force
        return $true
    } catch { return $false }
}

function Save-All([bool]$andRun) {
    try {
        if (-not (Test-Path $cfgPath)) { throw ("Config not found: " + $cfgPath) }
        $obj = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $obj) { throw "Bad config format" }

        # 规范为 hashtable，避免 PSObject 索引异常
        $j = [ordered]@{}
        foreach ($p in $obj.PSObject.Properties) { $j[$p.Name] = $p.Value }

        # Username
        $j['username'] = [string]$TxtUser.Text

        # Wi‑Fi names：按当前选择回写（学校网→恢复自动列表；JCI→仅 JCI）
        if ($RbJCI.IsChecked -eq $true) { $j['wifi_names'] = @('JCI') }
        if ($RbAuto.IsChecked -eq $true) { if ($script:__wifiNamesAuto) { $j['wifi_names'] = @($script:__wifiNamesAuto) } }
        # ISP and signal threshold
        $j['isp'] = Get-ISPValue
        $j['min_signal_percent'] = [int]$SldSignal.Value
        # Sync JCI rule ISP with current selection to avoid stale overrides during connect
        try {
            $rules = @()
            if ($j.Contains('ssid_rules')) { $rules = @($j['ssid_rules']) } else { $rules = @() }
            if (-not $rules) { $rules = @() }
            $found = $false
            for ($ri = 0; $ri -lt $rules.Count; $ri++) {
                $r = $rules[$ri]
                try {
                    $pattern = [string]$r.pattern
                    if ($pattern -eq 'JCI') { $r.isp = $j['isp']; $rules[$ri] = $r; $found = $true; break }
                } catch {}
            }
            if (-not $found) { $rules += @(@{ pattern='JCI'; isp=$j['isp'] }) }
            $j['ssid_rules'] = $rules
        } catch {}

        # Browser
        $j['browser'] = Get-BrowserValue
        # 总是启用headless模式，因为开机自动连接时没有用户界面
        $j['headless'] = $true

        # Save config（写入稳定目录，同时保持根目录一致，避免用户看到两个不同配置）
        # 持久化 Windows 凭据ID
        if (-not $j.Contains('windows_credential_id') -or -not $j['windows_credential_id']) { $j['windows_credential_id'] = 'CampusWindowsCredential' }
        ($j | ConvertTo-Json -Depth 50) | Out-File -FilePath $cfgPath -Encoding UTF8 -Force
        try { ($j | ConvertTo-Json -Depth 50) | Out-File -FilePath (Join-Path $root 'config.json') -Encoding UTF8 -Force } catch {}

        # 处理密码保存（门户密码）
        $userPwdPlain = [string]$PwdBox.Password
        $credId = [string]$j['credential_id']
        if (-not $credId -or $credId.Trim().Length -eq 0) { $credId = 'CampusPortalCredential' }
        
        # 更严格的占位符检测逻辑
        $isPlaceholder = $false
        try {
            # 多重检查：1) 占位符标记激活 2) 密码与占位符文本完全一致 3) 原始哈希存在
            if ($script:__pwdPlaceholderActive -and 
                ([string]$PwdBox.Password -eq [string]$script:__pwdPlaceholderText) -and
                ($null -ne $script:__pwdOriginalHash)) { 
                $isPlaceholder = $true 
            }
        } catch {}

        # 获取Windows密码（识别占位符）
        $winPassword = [string]$WinPwdBox.Password
        $hasWinPassword = $false
        $isWinPlaceholder = $false
        try {
            if ($script:__winPwdPlaceholderActive -and ([string]$WinPwdBox.Password -eq [string]$script:__winPwdPlaceholderText)) { $isWinPlaceholder = $true }
        } catch {}
        
        # 先尝试从已保存的密码中加载（无论是否为占位符）
        try {
            if (-not (Get-Command Load-Secret -ErrorAction SilentlyContinue)) { Import-Module (Join-Path $modulesPath 'security.psm1') -Force }
            $winCredId = if ($j['windows_credential_id']) { [string]$j['windows_credential_id'] } else { 'CampusWindowsCredential' }
            $wp0 = Load-Secret -Id $winCredId
            if ($wp0 -and ([string]$wp0).Trim().Length -gt 0) { 
                # 如果是占位符，使用已保存的密码
                if ($isWinPlaceholder) {
                    $winPassword = [string]$wp0
                }
                # 无论是否为占位符，只要能读取到已保存的密码，就视为有密码
                $hasWinPassword = $true
            }
        } catch {}
        
        # 如果不是占位符且用户输入了新密码，优先使用用户输入
        if (-not $isWinPlaceholder -and $winPassword -and $winPassword.Trim().Length -gt 0) { 
            $hasWinPassword = $true 
        }

        # 用户实际输入了新密码 → 覆盖保存
        if (-not $isPlaceholder -and $userPwdPlain -and $userPwdPlain.Trim().Length -gt 0) {
            # 额外检查：确保不是意外保存占位符字符
            if ($userPwdPlain -ne $script:__pwdPlaceholderText) {
                try {
                    if (-not (Get-Command Save-Secret -ErrorAction SilentlyContinue)) { Import-Module (Join-Path $modulesPath 'security.psm1') -Force }
                    
                    if ($hasWinPassword) {
                        # 有Windows密码：使用用户DPAPI保存
                        $sec = ConvertTo-SecureString -String $userPwdPlain -AsPlainText -Force
                        Save-Secret -Id $credId -Secret $sec | Out-Null
                    } else {
                        # 无Windows密码：同时使用DPAPI和系统级存储
                        $sec = ConvertTo-SecureString -String $userPwdPlain -AsPlainText -Force
                        Save-Secret -Id $credId -Secret $sec | Out-Null
                        Save-SystemSecret -Id $credId -PlainPassword $userPwdPlain | Out-Null
                    }
                    
                    # 同步到稳定目录
                    $rootSecret = Join-Path $root 'secrets.json'
                    if (Test-Path $rootSecret) { try { Copy-Item $rootSecret -Destination (Join-Path $stableRoot 'secrets.json') -Force -ErrorAction SilentlyContinue } catch {} }
                } catch { }
            }
        }

        # 保存 Windows 密码（若用户输入了新密码）
        if ($hasWinPassword) {
            try {
                if (-not (Get-Command Save-Secret -ErrorAction SilentlyContinue)) { Import-Module (Join-Path $modulesPath 'security.psm1') -Force }
                $winCredId2 = if ($j['windows_credential_id']) { [string]$j['windows_credential_id'] } else { 'CampusWindowsCredential' }
                $secWin = ConvertTo-SecureString -String $winPassword -AsPlainText -Force
                Save-Secret -Id $winCredId2 -Secret $secWin | Out-Null
            } catch {}
        }
        
        # 用户清空了密码框（且不是占位符）→ 删除保存的密码
        if (-not $isPlaceholder -and (-not $userPwdPlain -or $userPwdPlain.Trim().Length -eq 0)) {
            foreach ($secPath in @((Join-Path $root 'secrets.json'), (Join-Path $stableRoot 'secrets.json'))) {
                if (-not (Test-Path $secPath)) { continue }
                try {
                    $raw = Get-Content $secPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($raw) { $raw.PSObject.Properties.Remove($credId) | Out-Null; ($raw | ConvertTo-Json -Depth 20) | Out-File -FilePath $secPath -Encoding UTF8 -Force }
                } catch { }
            }
        }
        # 若为占位符且未修改 → 保留原有密钥，不做任何变更

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

        # register scheduled task to run stable start_auth at system startup
        $delay = 7
        try {
            if ($j.Contains('autostart_delay_sec') -and $j['autostart_delay_sec']) { $delay = [int]$j['autostart_delay_sec'] }
        } catch {}
        $authPath = Join-Path $stableRoot 'scripts\start_auth.ps1'
        $argString = ('-WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $authPath)
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argString
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $trigger.Delay = ('PT{0}S' -f $delay)

        try {
            if ($hasWinPassword) {
                # 有Windows密码：使用用户账号运行
                try {
                    # 获取完整的用户名格式（计算机名\用户名）
                    $fullUserName = $env:USERDOMAIN + '\' + $env:USERNAME
                    Register-ScheduledTask -TaskName 'CampusPortalAutoConnect' -Action $action -Trigger $trigger -User $fullUserName -Password $winPassword -RunLevel Highest -Force -ErrorAction Stop | Out-Null
                } catch {
                    # 如果完整格式失败，尝试只用用户名
                    try {
                        Register-ScheduledTask -TaskName 'CampusPortalAutoConnect' -Action $action -Trigger $trigger -User $env:USERNAME -Password $winPassword -RunLevel Highest -Force -ErrorAction Stop | Out-Null
                    } catch {
                        # 如果用户账户注册都失败，回退到SYSTEM
                        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
                        Register-ScheduledTask -TaskName 'CampusPortalAutoConnect' -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
                    }
                }
            } else {
                # 无Windows密码：使用SYSTEM账号运行
                $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
                Register-ScheduledTask -TaskName 'CampusPortalAutoConnect' -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
            }
        } catch { Show-Error ("Task registration failed: " + $_.Exception.Message) }

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
