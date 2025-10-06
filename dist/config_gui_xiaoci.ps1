param()

# Skip admin check if launched from exe (which already has admin rights)
if (-not $env:CAMPUSNET_SKIP_ADMIN_CHECK) {
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
}

# Skip STA check if launched from exe (which already runs in STA mode)
if (-not $env:CAMPUSNET_SKIP_ADMIN_CHECK) {
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
}

$ErrorActionPreference = 'SilentlyContinue'
# Skip console encoding in noConsole mode
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# Paths
$root = Split-Path $PSScriptRoot -Parent
$cfgPath = Join-Path $root 'config.json'
$modulesPath = Join-Path $root 'scripts\modules'
$startScript = Join-Path $root 'scripts\start_auth.ps1'

try { Import-Module (Join-Path $modulesPath 'security.psm1') -Force -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction SilentlyContinue } catch {}
try { Import-Module (Join-Path $modulesPath 'wifi.psm1') -Force -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction SilentlyContinue } catch {}

# ============ Donation Dialog Function ============
function Show-DonationDialog {
    # Get current language
    $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
    
    $donationWin = New-Object System.Windows.Window
    $donationWin.WindowStyle = 'None'
    $donationWin.AllowsTransparency = $true
    $donationWin.Background = 'Transparent'
    $donationWin.Width = 450
    $donationWin.Height = 650
    $donationWin.WindowStartupLocation = 'CenterScreen'
    $donationWin.ResizeMode = 'NoResize'
    $donationWin.Topmost = $true
    
    # 主边框（跟随主题）
    $donationBorder = New-Object System.Windows.Controls.Border
    $donationBorder.CornerRadius = 15
    $donationBorder.Padding = '25'
    $donationTheme = $script:themes[$script:currentTheme]
    $donationBorder.Background = $donationTheme.DialogBg
    $donationBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $donationBorder.Effect.BlurRadius = 25
    $donationBorder.Effect.ShadowDepth = 5
    $donationBorder.Effect.Opacity = 0.3
    
    # 添加拖动功能
    $donationBorder.Add_MouseLeftButtonDown({
        param($s, $e)
        try { $donationWin.DragMove() } catch {}
    })
    $donationBorder.Cursor = 'Hand'
    
    $donationStack = New-Object System.Windows.Controls.StackPanel
    
    # 标题
    $donationTitle = New-Object System.Windows.Controls.TextBlock
    $donationTitle.Text = $script:texts[$lang].DonationTitle
    $donationTitle.FontSize = 24
    $donationTitle.FontWeight = 'Bold'
    $donationTitle.Foreground = $donationTheme.DialogTitle
    $donationTitle.TextAlignment = 'Center'
    $donationTitle.Margin = '0,10,0,15'
    [void]$donationStack.Children.Add($donationTitle)
    
    # 温馨文案
    $donationMessage = New-Object System.Windows.Controls.TextBlock
    $donationMessage.Text = $script:texts[$lang].DonationMessage
    $donationMessage.FontSize = 13
    $donationMessage.Foreground = $donationTheme.DialogText
    $donationMessage.TextAlignment = 'Center'
    $donationMessage.TextWrapping = 'Wrap'
    $donationMessage.Margin = '0,0,0,20'
    [void]$donationStack.Children.Add($donationMessage)
    
    # 收款码图片
    $qrCodeBorder = New-Object System.Windows.Controls.Border
    $qrCodeBorder.Width = 350
    $qrCodeBorder.Height = 350
    $qrCodeBorder.CornerRadius = 10
    $qrCodeBorder.Background = 'White'
    $qrCodeBorder.BorderBrush = '#FFEDD4B0'
    $qrCodeBorder.BorderThickness = 2
    $qrCodeBorder.Margin = '0,0,0,20'
    
    $qrCodeImagePath = Join-Path $PSScriptRoot 'donation_qrcode.png'
    if (Test-Path $qrCodeImagePath) {
        $qrCodeImage = New-Object System.Windows.Controls.Image
        $qrCodeImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([Uri]::new($qrCodeImagePath))
        $qrCodeImage.Stretch = 'Uniform'
        $qrCodeImage.Margin = '5'
        $qrCodeBorder.Child = $qrCodeImage
    } else {
        # 如果图片不存在，显示提示文字
        $placeholderText = New-Object System.Windows.Controls.TextBlock
        $placeholderText.Text = '请将收款码保存为：' + "`n" + 'donation_qrcode.png' + "`n" + '并放置在dist文件夹中'
        $placeholderText.FontSize = 12
        $placeholderText.Foreground = '#FF95A5A6'
        $placeholderText.TextAlignment = 'Center'
        $placeholderText.VerticalAlignment = 'Center'
        $placeholderText.TextWrapping = 'Wrap'
        $qrCodeBorder.Child = $placeholderText
    }
    
    [void]$donationStack.Children.Add($qrCodeBorder)
    
    # 感谢文字
    $thanksText = New-Object System.Windows.Controls.TextBlock
    $thanksText.Text = $script:texts[$lang].DonationThanks
    $thanksText.FontSize = 11
    $thanksText.Foreground = $donationTheme.DialogTitle
    $thanksText.TextAlignment = 'Center'
    $thanksText.Margin = '0,0,0,15'
    [void]$donationStack.Children.Add($thanksText)
    
    # 关闭按钮
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = $script:texts[$lang].DonationClose
    $closeBtn.Width = 120
    $closeBtn.Height = 36
    $closeBtn.FontSize = 14
    $closeBtn.FontWeight = 'Bold'
    $closeBtn.Foreground = $donationTheme.DialogAccentFg
    $closeBtn.Background = $donationTheme.DialogAccent
    $closeBtn.BorderThickness = 0
    $closeBtn.Cursor = 'Hand'
    $closeBtn.HorizontalAlignment = 'Center'
    $closeBtn.Add_Click({ $donationWin.Close() })
    [void]$donationStack.Children.Add($closeBtn)
    
    # 作者名提示
    $authorNotice = New-Object System.Windows.Controls.TextBlock
    $authorNotice.Text = $script:texts[$lang].DonationAuthorNotice
    $authorNotice.FontSize = 10
    $authorNotice.Foreground = '#FF95A5A6'
    $authorNotice.TextAlignment = 'Center'
    $authorNotice.Margin = '0,10,0,0'
    [void]$donationStack.Children.Add($authorNotice)
    
    $donationBorder.Child = $donationStack
    $donationWin.Content = $donationBorder
    
    [void]$donationWin.ShowDialog()
}

# ============ About Dialog Function ============
function Show-AboutDialog {
    # Get current language
    $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
    
    $aboutWin = New-Object System.Windows.Window
    $aboutWin.WindowStyle = 'None'
    $aboutWin.AllowsTransparency = $true
    $aboutWin.Background = 'Transparent'
    $aboutWin.Width = 550
    $aboutWin.Height = 600
    $aboutWin.WindowStartupLocation = 'CenterScreen'
    $aboutWin.ResizeMode = 'NoResize'
    $aboutWin.Topmost = $true
    
    # 主边框（跟随主题）
    $aboutBorder = New-Object System.Windows.Controls.Border
    $aboutBorder.CornerRadius = 15
    $aboutBorder.Padding = '30'
    $aboutTheme = $script:themes[$script:currentTheme]
    $aboutBorder.Background = $aboutTheme.DialogBg
    $aboutBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $aboutBorder.Effect.BlurRadius = 25
    $aboutBorder.Effect.ShadowDepth = 5
    $aboutBorder.Effect.Opacity = 0.3
    
    # 添加拖动功能
    $aboutBorder.Add_MouseLeftButtonDown({
        param($s, $e)
        try { $aboutWin.DragMove() } catch {}
    })
    $aboutBorder.Cursor = 'Hand'
    
    $aboutStack = New-Object System.Windows.Controls.StackPanel
    
    # 标题
    $aboutTitle = New-Object System.Windows.Controls.TextBlock
    $aboutTitle.Text = $script:texts[$lang].AboutTitle
    $aboutTitle.FontSize = 24
    $aboutTitle.FontWeight = 'Bold'
    $aboutTitle.Foreground = $aboutTheme.DialogTitle
    $aboutTitle.TextAlignment = 'Center'
    $aboutTitle.Margin = '0,0,0,20'
    [void]$aboutStack.Children.Add($aboutTitle)
    
    # 版本信息
    $versionText = New-Object System.Windows.Controls.TextBlock
    $versionText.Text = $script:texts[$lang].AboutVersion
    $versionText.FontSize = 14
    $versionText.Foreground = $aboutTheme.DialogText
    $versionText.TextAlignment = 'Center'
    $versionText.Margin = '0,0,0,25'
    [void]$aboutStack.Children.Add($versionText)
    
    # 分隔线
    $separator1 = New-Object System.Windows.Controls.Border
    $separator1.Height = 2
    $separator1.Background = '#FFFFD9A8'
    $separator1.Margin = '0,0,0,20'
    $separator1.Opacity = 0.5
    [void]$aboutStack.Children.Add($separator1)
    
    # 隐私说明标题
    $privacyTitle = New-Object System.Windows.Controls.TextBlock
    $privacyTitle.Text = $script:texts[$lang].AboutUsageTitle
    $privacyTitle.FontSize = 16
    $privacyTitle.FontWeight = 'Bold'
    $privacyTitle.Foreground = $aboutTheme.DialogTitle
    $privacyTitle.Margin = '0,0,0,15'
    [void]$aboutStack.Children.Add($privacyTitle)
    
    # 隐私说明内容
    $privacyScroll = New-Object System.Windows.Controls.ScrollViewer
    $privacyScroll.MaxHeight = 280
    $privacyScroll.VerticalScrollBarVisibility = 'Auto'
    $privacyScroll.Margin = '0,0,0,20'
    
    $privacyText = New-Object System.Windows.Controls.TextBlock
    $privacyText.Text = $script:texts[$lang].AboutUsageContent
    $privacyText.FontSize = 12
    $privacyText.Foreground = $aboutTheme.DialogText
    $privacyText.TextWrapping = 'Wrap'
    $privacyText.LineHeight = 20
    $privacyText.Padding = '10'
    $privacyScroll.Content = $privacyText
    [void]$aboutStack.Children.Add($privacyScroll)
    
    # 分隔线
    $separator2 = New-Object System.Windows.Controls.Border
    $separator2.Height = 2
    $separator2.Background = '#FFFFD9A8'
    $separator2.Margin = '0,0,0,20'
    $separator2.Opacity = 0.5
    [void]$aboutStack.Children.Add($separator2)
    
    # 版权信息
    $copyrightText = New-Object System.Windows.Controls.TextBlock
    $copyrightText.Text = $script:texts[$lang].AboutCopyright
    $copyrightText.FontSize = 11
    $copyrightText.Foreground = '#FF95A5A6'
    $copyrightText.TextAlignment = 'Center'
    $copyrightText.Margin = '0,0,0,15'
    [void]$aboutStack.Children.Add($copyrightText)
    
    # 关闭按钮
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = $script:texts[$lang].AboutCloseBtn
    $closeBtn.Width = 120
    $closeBtn.Height = 36
    $closeBtn.FontSize = 14
    $closeBtn.FontWeight = 'Bold'
    $closeBtn.Foreground = $aboutTheme.DialogAccentFg
    $closeBtn.Background = $aboutTheme.DialogAccent
    $closeBtn.BorderThickness = 0
    $closeBtn.Cursor = 'Hand'
    $closeBtn.HorizontalAlignment = 'Center'
    $closeBtn.Add_Click({ $aboutWin.Close() })
    [void]$aboutStack.Children.Add($closeBtn)
    
    $aboutBorder.Child = $aboutStack
    $aboutWin.Content = $aboutBorder
    
    [void]$aboutWin.ShowDialog()
}

# ============ Quick Guide Dialog Function ============
function Show-QuickGuide {
    # Get current language
    $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
    
    $guideWin = New-Object System.Windows.Window
    $guideWin.WindowStyle = 'None'
    $guideWin.AllowsTransparency = $true
    $guideWin.Background = 'Transparent'
    $guideWin.Width = 580
    $guideWin.SizeToContent = 'Height'
    $guideWin.WindowStartupLocation = 'CenterScreen'
    $guideWin.ResizeMode = 'NoResize'
    $guideWin.Topmost = $true
    
    $guideBorder = New-Object System.Windows.Controls.Border
    $guideBorder.CornerRadius = 20
    $guideBorder.Background = New-Object System.Windows.Media.LinearGradientBrush
    $guideBorder.Background.StartPoint = '0,0'
    $guideBorder.Background.EndPoint = '1,1'
    $stop1 = New-Object System.Windows.Media.GradientStop
    $stop1.Color = '#FFFFF9F0'
    $stop1.Offset = 0
    $stop2 = New-Object System.Windows.Media.GradientStop
    $stop2.Color = '#FFFFF0E6'
    $stop2.Offset = 1
    $guideBorder.Background.GradientStops.Add($stop1)
    $guideBorder.Background.GradientStops.Add($stop2)
    $guideBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $guideBorder.Effect.BlurRadius = 30
    $guideBorder.Effect.ShadowDepth = 0
    $guideBorder.Effect.Opacity = 0.3
    $guideBorder.Effect.Color = '#FF000000'
    $guideBorder.Padding = 40
    $guideBorder.Cursor = 'Hand'
    
    $guideStack = New-Object System.Windows.Controls.StackPanel
    
    # Title row with language toggle button
    $titleGrid = New-Object System.Windows.Controls.Grid
    $titleGrid.Margin = '0,0,0,20'
    
    # Define three columns for the grid
    $col1 = New-Object System.Windows.Controls.ColumnDefinition
    $col1.Width = 'Auto'  # Language button column
    $col2 = New-Object System.Windows.Controls.ColumnDefinition
    $col2.Width = '*'     # Title column (takes remaining space)
    $col3 = New-Object System.Windows.Controls.ColumnDefinition
    $col3.Width = 'Auto'  # Right spacer (for symmetry)
    $titleGrid.ColumnDefinitions.Add($col1)
    $titleGrid.ColumnDefinitions.Add($col2)
    $titleGrid.ColumnDefinitions.Add($col3)
    
    # Language toggle button (left column)
    $langBtn = New-Object System.Windows.Controls.Button
    $langBtn.Content = if ($lang -eq 'CN') { '🌐 EN' } else { '🌐 中文' }
    $langBtn.Width = 80
    $langBtn.Height = 35
    $langBtn.FontSize = 14
    $langBtn.FontWeight = 'Bold'
    $langBtn.Background = '#FFD4A574'
    $langBtn.Foreground = 'White'
    $langBtn.BorderThickness = 0
    $langBtn.Cursor = 'Hand'
    $langBtn.HorizontalAlignment = 'Left'
    $langBtn.VerticalAlignment = 'Center'
    $langBtn.Margin = '0,0,10,0'
    [System.Windows.Controls.Grid]::SetColumn($langBtn, 0)
    
    # Title (center column)
    $titleBlock = New-Object System.Windows.Controls.TextBlock
    $titleBlock.Text = $script:texts[$lang].QuickGuideTitle
    $titleBlock.FontSize = 26
    $titleBlock.FontWeight = 'Bold'
    $titleBlock.Foreground = '#FFD4A574'
    $titleBlock.HorizontalAlignment = 'Center'
    $titleBlock.VerticalAlignment = 'Center'
    $titleBlock.Cursor = 'Arrow'
    [System.Windows.Controls.Grid]::SetColumn($titleBlock, 1)
    
    # Language button click event
    $langBtn.Add_Click({
        # Toggle language
        $script:isEnglish = -not $script:isEnglish
        
        # Close current window
        $guideWin.Close()
        
        # Show new guide with new language after a short delay
        Start-Sleep -Milliseconds 100
        Show-QuickGuide
    })
    
    # Prevent language button from triggering window drag
    $langBtn.Add_MouseDown({
        param($src, $e)
        $e.Handled = $true
    })
    
    [void]$titleGrid.Children.Add($langBtn)
    [void]$titleGrid.Children.Add($titleBlock)
    [void]$guideStack.Children.Add($titleGrid)
    
    # Content with colored text
    $contentBlock = New-Object System.Windows.Controls.TextBlock
    $contentBlock.FontSize = 14
    $contentBlock.LineHeight = 24
    $contentBlock.TextWrapping = 'Wrap'
    $contentBlock.Foreground = '#FF2C3E50'
    $contentBlock.Margin = '0,0,0,30'
    $contentBlock.Cursor = 'Arrow'
    
    # Build content with inline colored text
    if ($lang -eq 'CN') {
        $contentBlock.Inlines.Add("🎯 主要功能：`n")
        $contentBlock.Inlines.Add("• 自动连接校园所有认证网络`n")
        $contentBlock.Inlines.Add("• 看到桌面就有网，需要你动一下算我输`n")
        $contentBlock.Inlines.Add("• 多网络智能选择`n`n")
        
        $contentBlock.Inlines.Add("⚙️ 参数说明：`n")
        $contentBlock.Inlines.Add("• 学工号/密码：校园网登录凭据`n")
        $contentBlock.Inlines.Add("• 登录延迟：开机后延迟连接时间（0-3秒）`n")
        $contentBlock.Inlines.Add("• 运营商：选择网络运营商类型 ")
        $redRun1 = New-Object System.Windows.Documents.Run
        $redRun1.Text = "（没有校园网选择：无）"
        $redRun1.Foreground = 'Red'
        $redRun1.FontWeight = 'Bold'
        $contentBlock.Inlines.Add($redRun1)
        $contentBlock.Inlines.Add("`n• Wi-Fi选择：`n")
        $contentBlock.Inlines.Add("  - 学校网：自动连接7种网络（包含：JCI，")
        $greenRun = New-Object System.Windows.Documents.Run
        $greenRun.Text = "推荐"
        $greenRun.Foreground = 'Green'
        $greenRun.FontWeight = 'Bold'
        $contentBlock.Inlines.Add($greenRun)
        $contentBlock.Inlines.Add("） ")
        $redRun2 = New-Object System.Windows.Documents.Run
        $redRun2.Text = "（新厂校区选择：学校网）"
        $redRun2.Foreground = 'Red'
        $redRun2.FontWeight = 'Bold'
        $contentBlock.Inlines.Add($redRun2)
        $contentBlock.Inlines.Add("`n  - 校园网JCI：仅连接JCI网络（连接更快）`n")
        $contentBlock.Inlines.Add("• 信号阈值：低于此信号强度不连接`n")
        $contentBlock.Inlines.Add("• 浏览器：用于网页认证的浏览器`n`n")
        
        $contentBlock.Inlines.Add("📢 重要提示：`n")
        $contentBlock.Inlines.Add("✅ ")
        $importantRun = New-Object System.Windows.Documents.Run
        $importantRun.Text = "没有购买校园网也能使用本工具！！"
        $importantRun.Foreground = 'Red'
        $importantRun.FontWeight = 'Bold'
        $importantRun.FontSize = 16
        $contentBlock.Inlines.Add($importantRun)
        $contentBlock.Inlines.Add("`n✅ 可以使用学校的免费网络（所有教学楼以及教室、图书馆等）`n")
        $contentBlock.Inlines.Add("⚠️ 未购买校园网在寝室可能连不上网络`n")
        $contentBlock.Inlines.Add("✅ 但不影响在其他区域正常使用`n`n")
        
        $contentBlock.Inlines.Add("→ 右侧：远程支持、加入QQ群获取帮助")
    } else {
        $contentBlock.Inlines.Add("🎯 Main Features:`n")
        $contentBlock.Inlines.Add("• Auto-connect to all campus authenticated networks`n")
        $contentBlock.Inlines.Add("• Network ready when you see desktop, I lose if you need to do anything`n")
        $contentBlock.Inlines.Add("• Smart multi-network selection`n`n")
        
        $contentBlock.Inlines.Add("⚙️ Parameters:`n")
        $contentBlock.Inlines.Add("• Student ID/Password: Campus network credentials`n")
        $contentBlock.Inlines.Add("• Login Delay: Delay time after boot (0-3 seconds)`n")
        $contentBlock.Inlines.Add("• ISP: Select network operator type ")
        $redRun1 = New-Object System.Windows.Documents.Run
        $redRun1.Text = "(No campus net: select None)"
        $redRun1.Foreground = 'Red'
        $redRun1.FontWeight = 'Bold'
        $contentBlock.Inlines.Add($redRun1)
        $contentBlock.Inlines.Add("`n• Wi-Fi Selection:`n")
        $contentBlock.Inlines.Add("  - School Net: Connect 7 networks (includes: JCI, ")
        $greenRun = New-Object System.Windows.Documents.Run
        $greenRun.Text = "recommended"
        $greenRun.Foreground = 'Green'
        $greenRun.FontWeight = 'Bold'
        $contentBlock.Inlines.Add($greenRun)
        $contentBlock.Inlines.Add(") ")
        $redRun2 = New-Object System.Windows.Documents.Run
        $redRun2.Text = "(New campus: School Net)"
        $redRun2.Foreground = 'Red'
        $redRun2.FontWeight = 'Bold'
        $contentBlock.Inlines.Add($redRun2)
        $contentBlock.Inlines.Add("`n  - Campus Net JCI: Only JCI (faster connection)`n")
        $contentBlock.Inlines.Add("• Signal Threshold: Don't connect below this signal`n")
        $contentBlock.Inlines.Add("• Browser: Browser for web authentication`n`n")
        
        $contentBlock.Inlines.Add("📢 Important Notice:`n")
        $contentBlock.Inlines.Add("✅ ")
        $importantRun = New-Object System.Windows.Documents.Run
        $importantRun.Text = "You can use this tool WITHOUT purchasing campus internet!!"
        $importantRun.Foreground = 'Red'
        $importantRun.FontWeight = 'Bold'
        $importantRun.FontSize = 16
        $contentBlock.Inlines.Add($importantRun)
        $contentBlock.Inlines.Add("`n✅ Use school's free networks (all teaching buildings, classrooms, library, etc.)`n")
        $contentBlock.Inlines.Add("⚠️ May not connect in dorm without paid campus internet`n")
        $contentBlock.Inlines.Add("✅ Works normally in other areas`n`n")
        
        $contentBlock.Inlines.Add("→ Right side: Remote support, Join QQ group for help")
    }
    
    [void]$guideStack.Children.Add($contentBlock)
    
    # Close button
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = $script:texts[$lang].QuickGuideCloseBtn
    $closeBtn.Width = 200
    $closeBtn.Height = 45
    $closeBtn.FontSize = 16
    $closeBtn.FontWeight = 'Bold'
    $closeBtn.Background = '#FFD4A574'
    $closeBtn.Foreground = 'White'
    $closeBtn.BorderThickness = 0
    $closeBtn.Cursor = 'Hand'
    $closeBtn.HorizontalAlignment = 'Center'
    $closeBtn.Add_Click({ $guideWin.Close() })
    # Prevent close button from triggering window drag
    $closeBtn.Add_MouseLeftButtonDown({
        $_.Handled = $true
    })
    [void]$guideStack.Children.Add($closeBtn)
    
    $guideBorder.Child = $guideStack
    $guideWin.Content = $guideBorder
    
    # Enable window dragging
    $guideBorder.Add_MouseLeftButtonDown({
        try {
            $guideWin.DragMove()
        } catch {}
    })
    
    [void]$guideWin.ShowDialog()
}

# Custom styled message box functions
function Show-CustomDialog {
    param(
        [string]$Message,
        [string]$Title = '',
        [string]$Type = 'Info',  # Info, Error, Warning, Question
        [bool]$ShowCancel = $false
    )
    
    $dialogWin = New-Object System.Windows.Window
    $dialogWin.WindowStyle = 'None'
    $dialogWin.AllowsTransparency = $true
    $dialogWin.Background = 'Transparent'
    $dialogWin.Width = 500
    $dialogWin.SizeToContent = 'Height'
    $dialogWin.WindowStartupLocation = 'CenterScreen'
    $dialogWin.ResizeMode = 'NoResize'
    $dialogWin.Topmost = $true
    
    # Main border with shadow - 纯色或轻渐变取决于主题
    $border = New-Object System.Windows.Controls.Border
    $border.CornerRadius = 12
    $border.Padding = '0'
    
    $theme = $script:themes[$script:currentTheme]
    $border.Background = $theme.DialogBg
    
    $border.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $border.Effect.BlurRadius = 35
    $border.Effect.ShadowDepth = 0
    $border.Effect.Opacity = 0.20
    $border.Effect.Color = '#FF000000'
    
    # 添加拖动功能
    $border.Add_MouseLeftButtonDown({
        param($s, $e)
        try { $dialogWin.DragMove() } catch {}
    })
    $border.Cursor = 'Hand'
    
    $mainStack = New-Object System.Windows.Controls.StackPanel
    
    # Content area - 更宽敞的间距
    $contentStack = New-Object System.Windows.Controls.StackPanel
    $contentStack.Margin = '35,35,35,28'
    
    # Icon and Title row - 现代化设计
    if ($Title) {
        $titlePanel = New-Object System.Windows.Controls.StackPanel
        $titlePanel.Orientation = 'Horizontal'
        $titlePanel.Margin = '0,0,0,18'
        
        # 精致图标
        $iconText = New-Object System.Windows.Controls.TextBlock
        $iconText.FontSize = 24
        $iconText.Margin = '0,0,12,0'
        $iconText.VerticalAlignment = 'Center'
        $iconText.FontWeight = 'Bold'
        
        switch ($Type) {
            'Info' { $iconText.Text = '✓'; $iconText.Foreground = $theme.DialogIcon }
            'Error' { $iconText.Text = '✕'; $iconText.Foreground = $theme.DialogIcon }
            'Warning' { $iconText.Text = '⚠'; $iconText.Foreground = $theme.DialogIcon }
            'Question' { $iconText.Text = '?'; $iconText.Foreground = $theme.DialogIcon }
        }
        [void]$titlePanel.Children.Add($iconText)
        
        # 标题文字 - 简洁专业
        $titleText = New-Object System.Windows.Controls.TextBlock
        $titleText.Text = $Title
        $titleText.FontSize = 17
        $titleText.FontWeight = 'SemiBold'
        $titleText.Foreground = $theme.DialogTitle
        $titleText.VerticalAlignment = 'Center'
        [void]$titlePanel.Children.Add($titleText)
        
        [void]$contentStack.Children.Add($titlePanel)
    }
    
    # Message - 高级排版
    $msgText = New-Object System.Windows.Controls.TextBlock
    $msgText.Text = $Message
    $msgText.TextWrapping = 'Wrap'
    $msgText.FontSize = 13.5
    $msgText.Foreground = $theme.DialogText
    $msgText.LineHeight = 24
    $msgText.Margin = '0,0,0,28'
    $msgText.FontFamily = 'Microsoft YaHei UI, Segoe UI'
    [void]$contentStack.Children.Add($msgText)
    
    # Buttons - 现代化设计
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = 'Horizontal'
    $btnPanel.HorizontalAlignment = 'Right'
    
    # 圆角按钮模板
    $buttonTemplate = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <Border Background="{TemplateBinding Background}" 
            BorderBrush="{TemplateBinding BorderBrush}" 
            BorderThickness="{TemplateBinding BorderThickness}" 
            CornerRadius="6">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
</ControlTemplate>
"@
    
    if ($ShowCancel) {
        # 取消按钮 - 简洁设计
        $btnNo = New-Object System.Windows.Controls.Button
        $btnNo.Content = if ($Type -eq 'Question') { '取消' } else { '取消' }
        $btnNo.Width = 88
        $btnNo.Height = 38
        $btnNo.Margin = '0,0,10,0'
        $btnNo.FontSize = 13
        $btnNo.Background = $theme.DialogCancelBg
        $btnNo.Foreground = $theme.DialogCancelFg
        $btnNo.BorderBrush = $theme.DialogBorder
        $btnNo.BorderThickness = '1'
        $btnNo.Cursor = 'Hand'
        $btnNo.FontFamily = 'Microsoft YaHei UI'
        $btnNo.Template = [System.Windows.Markup.XamlReader]::Parse($buttonTemplate)
        $btnNo.Add_MouseEnter({ $this.Background = '#FFF0F2F5' })
        $btnNo.Add_MouseLeave({ $this.Background = $theme.DialogCancelBg })
        $btnNo.Add_Click({
            $dialogWin.Tag = $false
            $dialogWin.Close()
        })
        [void]$btnPanel.Children.Add($btnNo)
    }
    
    # 确认按钮 - 高级配色
    $btnYes = New-Object System.Windows.Controls.Button
    $btnYes.Content = if ($ShowCancel -and $Type -eq 'Question') { '确认' } else { '确认' }
    $btnYes.Width = 88
    $btnYes.Height = 38
    $btnYes.FontSize = 13
    $btnYes.FontWeight = 'Medium'
    $btnYes.Foreground = '#FFFFFFFF'
    $btnYes.BorderThickness = 0
    $btnYes.Cursor = 'Hand'
    $btnYes.FontFamily = 'Microsoft YaHei UI'
    
    # 使用主题强调色
    $btnYes.Background = $theme.DialogAccent
    $btnYes.Foreground = $theme.DialogAccentFg
    $btnYes.Add_MouseEnter({ $this.Opacity = 0.92 })
    $btnYes.Add_MouseLeave({ $this.Opacity = 1.0 })
    
    $btnYes.Template = [System.Windows.Markup.XamlReader]::Parse($buttonTemplate)
    $btnYes.Add_Click({
        $dialogWin.Tag = $true
        $dialogWin.Close()
    })
    [void]$btnPanel.Children.Add($btnYes)
    
    [void]$contentStack.Children.Add($btnPanel)
    [void]$mainStack.Children.Add($contentStack)
    
    $border.Child = $mainStack
    
    # Close button (X) at top right - 简洁设计
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = '×'
    $closeBtn.Width = 30
    $closeBtn.Height = 30
    $closeBtn.FontSize = 18
    $closeBtn.FontWeight = 'Normal'
    $closeBtn.Background = 'Transparent'
    $closeBtn.Foreground = '#FFB0B8BF'
    $closeBtn.BorderThickness = 0
    $closeBtn.Cursor = 'Hand'
    $closeBtn.HorizontalAlignment = 'Right'
    $closeBtn.VerticalAlignment = 'Top'
    $closeBtn.Margin = '0,8,8,0'
    
    $closeTemplate = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <Border Background="{TemplateBinding Background}" CornerRadius="15">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
</ControlTemplate>
"@
    $closeBtn.Template = [System.Windows.Markup.XamlReader]::Parse($closeTemplate)
    $closeBtn.Add_MouseEnter({ 
        $this.Foreground = '#FFE74C3C'
        $this.Background = '#FFF8F9FA'
    })
    $closeBtn.Add_MouseLeave({ 
        $this.Foreground = '#FFB0B8BF'
        $this.Background = 'Transparent'
    })
    $closeBtn.Add_Click({
        $dialogWin.Tag = $false
        $dialogWin.Close()
    })
    
    # 使用Grid布局
    $overlayGrid = New-Object System.Windows.Controls.Grid
    [void]$overlayGrid.Children.Add($border)
    [System.Windows.Controls.Panel]::SetZIndex($closeBtn, 99)
    [void]$overlayGrid.Children.Add($closeBtn)
    
    $dialogWin.Content = $overlayGrid
    
    $dialogWin.Tag = $false
    [void]$dialogWin.ShowDialog()
    return $dialogWin.Tag
}

function Show-Info([string]$msg, [string]$title = '') { 
    [void](Show-CustomDialog -Message $msg -Title $title -Type 'Info')
}

function Show-Error([string]$msg, [string]$title = '') { 
    [void](Show-CustomDialog -Message $msg -Title $title -Type 'Error')
}

function Show-Question([string]$msg, [string]$title = '') {
    return (Show-CustomDialog -Message $msg -Title $title -Type 'Question' -ShowCancel $true)
}

Add-Type -AssemblyName PresentationFramework | Out-Null
Add-Type -AssemblyName PresentationCore | Out-Null
Add-Type -AssemblyName WindowsBase | Out-Null
try { Add-Type -AssemblyName System.Windows.Forms | Out-Null } catch {}

# Helper to compose Chinese text safely from Unicode code points (avoids file-encoding问题)
function CS { param([int[]]$u) return (-join ($u | ForEach-Object { [char]$_ })) }

# Build Window in code (avoid XAML encoding issues)
$window = New-Object System.Windows.Window
$window.Title = (CS @(0x6821,0x56ED,0x7F51,0x4E00,0x952E,0x5DE5,0x5177,0x0020,0x002D,0x0020,0x914D,0x7F6E))
$window.Width = 1080
$window.Height = 720
$window.WindowStartupLocation = 'CenterScreen'
$window.FontFamily = 'Microsoft YaHei UI, Segoe UI, Arial'
$window.FontSize = 13
$window.WindowStyle = 'None'
$window.AllowsTransparency = $true
$window.Background = 'Transparent'
$window.ResizeMode = 'CanResize'
$window.MinWidth = 900
$window.MinHeight = 600
[void]($window.Resources)

# Main container with rounded corners and shadow effect
$mainBorder = New-Object System.Windows.Controls.Border
$script:mainBorder = $mainBorder
$mainBorder.CornerRadius = '24'
$mainBorder.Background = New-Object System.Windows.Media.LinearGradientBrush
$mainBorder.Background.StartPoint = '0,0.5'
$mainBorder.Background.EndPoint = '1,0.5'
# 水平渐变 - 从左到右，配合整体渐变效果
$stop1 = New-Object System.Windows.Media.GradientStop; $stop1.Color = '#FFFFFBF5'; $stop1.Offset = 0
$stop2 = New-Object System.Windows.Media.GradientStop; $stop2.Color = '#FFFFFDF8'; $stop2.Offset = 0.35
$stop3 = New-Object System.Windows.Media.GradientStop; $stop3.Color = '#FFFFFEFB'; $stop3.Offset = 0.65
$stop4 = New-Object System.Windows.Media.GradientStop; $stop4.Color = '#FFFFFFFF'; $stop4.Offset = 1
$mainBorder.Background.GradientStops.Add($stop1)
$mainBorder.Background.GradientStops.Add($stop2)
$mainBorder.Background.GradientStops.Add($stop3)
$mainBorder.Background.GradientStops.Add($stop4)
$mainBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
$mainBorder.Effect.BlurRadius = 40
$mainBorder.Effect.ShadowDepth = 0
$mainBorder.Effect.Opacity = 0.3
$mainBorder.Effect.Color = '#FF000000'

$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = '0'

# Define three columns: left decorative panel + middle content panel + right info panel
$cd0 = New-Object System.Windows.Controls.ColumnDefinition; $cd0.Width='280'; [void]$grid.ColumnDefinitions.Add($cd0)
$cd1 = New-Object System.Windows.Controls.ColumnDefinition; $cd1.Width='*'; [void]$grid.ColumnDefinitions.Add($cd1)
$cd2 = New-Object System.Windows.Controls.ColumnDefinition; $cd2.Width='280';   [void]$grid.ColumnDefinitions.Add($cd2)

# ============ LEFT PANEL: Decorative Ceramic-style Panel ============
$leftPanel = New-Object System.Windows.Controls.Border
$script:leftPanel = $leftPanel
$leftPanel.CornerRadius = '24,0,0,24'
$leftPanel.Background = New-Object System.Windows.Media.LinearGradientBrush
$leftPanel.Background.StartPoint = '0,0'
$leftPanel.Background.EndPoint = '0,1'
# 深金黄色垂直渐变 - 丝滑过渡
$lgStop1 = New-Object System.Windows.Media.GradientStop; $lgStop1.Color = '#FFFFCC80'; $lgStop1.Offset = 0
$lgStop2 = New-Object System.Windows.Media.GradientStop; $lgStop2.Color = '#FFFFD090'; $lgStop2.Offset = 0.25
$lgStop3 = New-Object System.Windows.Media.GradientStop; $lgStop3.Color = '#FFFFD498'; $lgStop3.Offset = 0.50
$lgStop4 = New-Object System.Windows.Media.GradientStop; $lgStop4.Color = '#FFFFD8A0'; $lgStop4.Offset = 0.75
$lgStop5 = New-Object System.Windows.Media.GradientStop; $lgStop5.Color = '#FFFFDCA8'; $lgStop5.Offset = 1
$leftPanel.Background.GradientStops.Add($lgStop1)
$leftPanel.Background.GradientStops.Add($lgStop2)
$leftPanel.Background.GradientStops.Add($lgStop3)
$leftPanel.Background.GradientStops.Add($lgStop4)
$leftPanel.Background.GradientStops.Add($lgStop5)
[System.Windows.Controls.Grid]::SetColumn($leftPanel,0)
[void]$grid.Children.Add($leftPanel)

# Left panel content stack
$leftStack = New-Object System.Windows.Controls.StackPanel
$leftStack.VerticalAlignment = 'Center'
$leftStack.HorizontalAlignment = 'Center'
$leftStack.Margin = '30,60,30,60'

# Decorative circle (ceramic avatar placeholder) - Can be replaced with image
$avatarBorder = New-Object System.Windows.Controls.Border
$avatarBorder.Width = 150
$avatarBorder.Height = 150
$avatarBorder.CornerRadius = 75
$avatarBorder.Background = New-Object System.Windows.Media.LinearGradientBrush
$avatarBorder.Background.StartPoint = '0,0'
$avatarBorder.Background.EndPoint = '1,1'
$avStop1 = New-Object System.Windows.Media.GradientStop; $avStop1.Color = '#FFFFFFFF'; $avStop1.Offset = 0
$avStop2 = New-Object System.Windows.Media.GradientStop; $avStop2.Color = '#FFF0F8FF'; $avStop2.Offset = 1
$avatarBorder.Background.GradientStops.Add($avStop1)
$avatarBorder.Background.GradientStops.Add($avStop2)
$avatarBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
$avatarBorder.Effect.BlurRadius = 20
$avatarBorder.Effect.ShadowDepth = 5
$avatarBorder.Effect.Opacity = 0.25
$avatarBorder.Effect.Color = '#FF000000'
$avatarBorder.Margin = '0,0,0,30'
$avatarBorder.ClipToBounds = $true

$avatarGrid = New-Object System.Windows.Controls.Grid

# Try to load image if exists, otherwise use gradient circle
$avatarImagePath = Join-Path $PSScriptRoot 'avatar.png'
if (Test-Path $avatarImagePath) {
    $avatarImage = New-Object System.Windows.Controls.Image
    $avatarImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([Uri]::new($avatarImagePath))
    $avatarImage.Stretch = 'UniformToFill'
    # Apply circular clip geometry
    $avatarImage.Clip = New-Object System.Windows.Media.EllipseGeometry -Property @{
        Center = New-Object System.Windows.Point(75, 75)
        RadiusX = 75
        RadiusY = 75
    }
    [void]$avatarGrid.Children.Add($avatarImage)
} else {
    # Inner decorative element (default gradient)
    $innerCircle = New-Object System.Windows.Controls.Ellipse
    $innerCircle.Width = 100
    $innerCircle.Height = 100
    $innerCircle.Fill = New-Object System.Windows.Media.RadialGradientBrush
    $innerCircle.Fill.GradientStops.Add((New-Object System.Windows.Media.GradientStop -Property @{Color='#FFB8D4F1';Offset=0}))
    $innerCircle.Fill.GradientStops.Add((New-Object System.Windows.Media.GradientStop -Property @{Color='#FF8FB9E8';Offset=1}))
    $innerCircle.VerticalAlignment = 'Center'
    $innerCircle.HorizontalAlignment = 'Center'
    [void]$avatarGrid.Children.Add($innerCircle)
}

$avatarBorder.Child = $avatarGrid

[void]$leftStack.Children.Add($avatarBorder)

# Title with ceramic theme
$titleBlock = New-Object System.Windows.Controls.TextBlock
$script:titleBlock = $titleBlock
$titleBlock.Text = (CS @(0x5C0F,0x74F7))
$titleBlock.FontSize = 24
$titleBlock.FontWeight = 'Bold'
$titleBlock.Foreground = '#FF2C3E50'
$titleBlock.TextAlignment = 'Center'
$titleBlock.Margin = '0,0,0,10'
[void]$leftStack.Children.Add($titleBlock)

# Subtitle
$subtitleBlock = New-Object System.Windows.Controls.TextBlock
$script:subtitleBlock = $subtitleBlock
$subtitleBlock.Text = (CS @(0x5C0F,0x74F7,0x4E3A,0x4E3B,0x4EBA,0x8FDE,0x63A5,0x7F51,0x7EDC,0x8036,0xFF01))
$subtitleBlock.FontSize = 11
$subtitleBlock.Foreground = '#FF6B4423'
$subtitleBlock.TextAlignment = 'Center'
$subtitleBlock.Margin = '0,0,0,30'
$subtitleBlock.Opacity = 0.85
[void]$leftStack.Children.Add($subtitleBlock)

# Decorative dots
$dotsPanel = New-Object System.Windows.Controls.StackPanel
$dotsPanel.Orientation = 'Horizontal'
$dotsPanel.HorizontalAlignment = 'Center'
$dotsPanel.Margin = '0,15,0,15'
foreach ($color in @('#FFFF6B9D', '#FF4ECDC4', '#FF95E1D3')) {
    $dot = New-Object System.Windows.Controls.Ellipse
    $dot.Width = 10
    $dot.Height = 10
    $dot.Fill = $color
    $dot.Margin = '5,0'
    $dot.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $dot.Effect.BlurRadius = 8
    $dot.Effect.ShadowDepth = 0
    $dot.Effect.Opacity = 0.4
    [void]$dotsPanel.Children.Add($dot)
}
[void]$leftStack.Children.Add($dotsPanel)

# 请作者喝咖啡按钮
$donationBtn = New-Object System.Windows.Controls.Button
$donationBtn.Content = '☕ 请作者喝咖啡'  # 默认中文，语言切换时会更新
$script:donationBtn = $donationBtn
$donationBtn.Width = 160
$donationBtn.Height = 38
$donationBtn.FontSize = 12
$donationBtn.FontWeight = 'Medium'
$donationBtn.Foreground = '#FFFFFFFF'
$donationBtn.BorderThickness = 0
$donationBtn.Cursor = 'Hand'
$donationBtn.HorizontalAlignment = 'Center'
$donationBtn.Margin = '0,0,0,0'

# 咖啡色渐变背景
$coffeeBrush = New-Object System.Windows.Media.LinearGradientBrush
$coffeeBrush.StartPoint = '0,0'
$coffeeBrush.EndPoint = '1,1'
$coffeeStop1 = New-Object System.Windows.Media.GradientStop; $coffeeStop1.Color = '#FFD4A574'; $coffeeStop1.Offset = 0
$coffeeStop2 = New-Object System.Windows.Media.GradientStop; $coffeeStop2.Color = '#FFCF9A5D'; $coffeeStop2.Offset = 1
$coffeeBrush.GradientStops.Add($coffeeStop1)
$coffeeBrush.GradientStops.Add($coffeeStop2)
$donationBtn.Background = $coffeeBrush

# 按钮阴影效果
$donationBtn.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
$donationBtn.Effect.BlurRadius = 12
$donationBtn.Effect.ShadowDepth = 3
$donationBtn.Effect.Opacity = 0.3
$donationBtn.Effect.Color = '#FFD4A574'

# 圆角模板
$btnTemplate = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <Border Background="{TemplateBinding Background}" 
            BorderBrush="{TemplateBinding BorderBrush}" 
            BorderThickness="{TemplateBinding BorderThickness}" 
            CornerRadius="19">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
</ControlTemplate>
"@
$donationBtn.Template = [System.Windows.Markup.XamlReader]::Parse($btnTemplate)

# 添加悬停效果
$donationBtn.Add_MouseEnter({
    $hoverBrush = New-Object System.Windows.Media.LinearGradientBrush
    $hoverBrush.StartPoint = '0,0'
    $hoverBrush.EndPoint = '1,1'
    $hoverStop1 = New-Object System.Windows.Media.GradientStop; $hoverStop1.Color = '#FFDEB887'; $hoverStop1.Offset = 0
    $hoverStop2 = New-Object System.Windows.Media.GradientStop; $hoverStop2.Color = '#FFD4A574'; $hoverStop2.Offset = 1
    $hoverBrush.GradientStops.Add($hoverStop1)
    $hoverBrush.GradientStops.Add($hoverStop2)
    $this.Background = $hoverBrush
})

$donationBtn.Add_MouseLeave({
    $normalBrush = New-Object System.Windows.Media.LinearGradientBrush
    $normalBrush.StartPoint = '0,0'
    $normalBrush.EndPoint = '1,1'
    $normalStop1 = New-Object System.Windows.Media.GradientStop; $normalStop1.Color = '#FFD4A574'; $normalStop1.Offset = 0
    $normalStop2 = New-Object System.Windows.Media.GradientStop; $normalStop2.Color = '#FFCF9A5D'; $normalStop2.Offset = 1
    $normalBrush.GradientStops.Add($normalStop1)
    $normalBrush.GradientStops.Add($normalStop2)
    $this.Background = $normalBrush
})

$donationBtn.Add_Click({
    Show-DonationDialog
})

[void]$leftStack.Children.Add($donationBtn)

$leftPanel.Child = $leftStack

# ============ GRADIENT TRANSITION LAYER ============
$gradientLayer = New-Object System.Windows.Controls.Border
$script:gradientLayer = $gradientLayer
$gradientLayer.Width = 220
$gradientLayer.HorizontalAlignment = 'Left'
$gradientLayer.Background = New-Object System.Windows.Media.LinearGradientBrush
$gradientLayer.Background.StartPoint = '0,0'
$gradientLayer.Background.EndPoint = '1,0'
# 丝滑的水平渐变过渡 - 从深金黄到纯白
$gStop1 = New-Object System.Windows.Media.GradientStop; $gStop1.Color = '#FFFFDCA8'; $gStop1.Offset = 0
$gStop2 = New-Object System.Windows.Media.GradientStop; $gStop2.Color = '#FFFFE4B8'; $gStop2.Offset = 0.15
$gStop3 = New-Object System.Windows.Media.GradientStop; $gStop3.Color = '#FFFFECC8'; $gStop3.Offset = 0.30
$gStop4 = New-Object System.Windows.Media.GradientStop; $gStop4.Color = '#FFFFF2D8'; $gStop4.Offset = 0.45
$gStop5 = New-Object System.Windows.Media.GradientStop; $gStop5.Color = '#FFFFF6E5'; $gStop5.Offset = 0.60
$gStop6 = New-Object System.Windows.Media.GradientStop; $gStop6.Color = '#FFFFFAEF'; $gStop6.Offset = 0.75
$gStop7 = New-Object System.Windows.Media.GradientStop; $gStop7.Color = '#FFFFFDF8'; $gStop7.Offset = 0.90
$gStop8 = New-Object System.Windows.Media.GradientStop; $gStop8.Color = '#FFFFFFFF'; $gStop8.Offset = 1
$gradientLayer.Background.GradientStops.Add($gStop1)
$gradientLayer.Background.GradientStops.Add($gStop2)
$gradientLayer.Background.GradientStops.Add($gStop3)
$gradientLayer.Background.GradientStops.Add($gStop4)
$gradientLayer.Background.GradientStops.Add($gStop5)
$gradientLayer.Background.GradientStops.Add($gStop6)
$gradientLayer.Background.GradientStops.Add($gStop7)
$gradientLayer.Background.GradientStops.Add($gStop8)
[System.Windows.Controls.Grid]::SetColumn($gradientLayer,1)
$gradientLayer.IsHitTestVisible = $false
[void]$grid.Children.Add($gradientLayer)

# ============ MIDDLE PANEL: Content Area ============
$middlePanel = New-Object System.Windows.Controls.Grid
[System.Windows.Controls.Grid]::SetColumn($middlePanel,1)
[void]$grid.Children.Add($middlePanel)

# ============ RIGHT PANEL: Info Area (for future use) ============
$rightPanel = New-Object System.Windows.Controls.Border
$script:rightPanel = $rightPanel
$rightPanel.CornerRadius = '0,24,24,0'
$rightPanel.Background = New-Object System.Windows.Media.LinearGradientBrush
$rightPanel.Background.StartPoint = '0,0'
$rightPanel.Background.EndPoint = '0,1'
$rpStop1 = New-Object System.Windows.Media.GradientStop; $rpStop1.Color = '#FFFFF9F0'; $rpStop1.Offset = 0
$rpStop2 = New-Object System.Windows.Media.GradientStop; $rpStop2.Color = '#FFFFF5EB'; $rpStop2.Offset = 1
$rightPanel.Background.GradientStops.Add($rpStop1)
$rightPanel.Background.GradientStops.Add($rpStop2)
[System.Windows.Controls.Grid]::SetColumn($rightPanel,2)
[void]$grid.Children.Add($rightPanel)

# Right panel content stack
$rightStack = New-Object System.Windows.Controls.StackPanel
$rightStack.VerticalAlignment = 'Stretch'
$rightStack.HorizontalAlignment = 'Stretch'
$rightStack.Margin = '15,70,15,15'

# 服务标题
$serviceTitle = New-Object System.Windows.Controls.TextBlock
$serviceTitle.Text = '💼 增值服务'
$serviceTitle.FontSize = 16
$serviceTitle.FontWeight = 'Bold'
$serviceTitle.Foreground = '#FF6B4423'
$serviceTitle.TextAlignment = 'Center'
$serviceTitle.Margin = '0,0,0,15'
[void]$rightStack.Children.Add($serviceTitle)

# 远程技术支持卡片
$supportCard = New-Object System.Windows.Controls.Border
$supportCard.Background = '#FFFFFFFF'
$supportCard.BorderBrush = '#FFEDD4B0'
$supportCard.BorderThickness = 1.5
$supportCard.CornerRadius = 10
$supportCard.Padding = '12,10'
$supportCard.Margin = '0,0,0,8'
$supportCard.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
$supportCard.Effect.BlurRadius = 6
$supportCard.Effect.ShadowDepth = 2
$supportCard.Effect.Opacity = 0.1

$supportStack = New-Object System.Windows.Controls.StackPanel

$supportHeader = New-Object System.Windows.Controls.TextBlock
$supportHeader.Text = '🛠️ 远程技术支持'
$supportHeader.FontSize = 12
$supportHeader.FontWeight = 'Bold'
$supportHeader.Foreground = '#FF5D4E37'
$supportHeader.Margin = '0,0,0,5'
[void]$supportStack.Children.Add($supportHeader)

$wechatInfo = New-Object System.Windows.Controls.TextBlock
$wechatInfo.Text = '微信：HelloAiEngine'
$wechatInfo.FontSize = 10
$wechatInfo.Foreground = '#FF8B6F47'
$wechatInfo.Margin = '0,0,0,8'
[void]$supportStack.Children.Add($wechatInfo)

# 添加一键复制微信号按钮
$wechatCopyBtn = New-Object System.Windows.Controls.Button
$wechatCopyBtn.Content = '📋 复制微信号'
$wechatCopyBtn.Height = 26
$wechatCopyBtn.FontSize = 9
$wechatCopyBtn.Background = '#FFFFF5E6'
$wechatCopyBtn.Foreground = '#FF8B6F47'
$wechatCopyBtn.BorderBrush = '#FFEDD4B0'
$wechatCopyBtn.BorderThickness = 1
$wechatCopyBtn.Cursor = 'Hand'
$wechatCopyBtn.Margin = '0,0,0,8'
$wechatCopyTemplate = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <Border Background="{TemplateBinding Background}" 
            BorderBrush="{TemplateBinding BorderBrush}" 
            BorderThickness="{TemplateBinding BorderThickness}" 
            CornerRadius="5">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
</ControlTemplate>
"@
$wechatCopyBtn.Template = [System.Windows.Markup.XamlReader]::Parse($wechatCopyTemplate)
$wechatCopyBtn.Add_Click({
    try {
        $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
        [System.Windows.Clipboard]::SetText('HelloAiEngine')
        Show-Info $script:texts[$lang].WechatCopySuccess $script:texts[$lang].CopySuccessTitle
    } catch {
        $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
        Show-Error $script:texts[$lang].WechatCopyFail $script:texts[$lang].ErrorTitle
    }
})
[void]$supportStack.Children.Add($wechatCopyBtn)

$supportCard.Child = $supportStack
[void]$rightStack.Children.Add($supportCard)

# 服务项目列表
$services = @(
    @{ Icon = '💻'; Text = '深度内存清理'; Price = '10元/次'; Desc = '自动释放内存，优化性能' }
    @{ Icon = '📦'; Text = '系统垃圾清理'; Price = '20元/次'; Desc = '深度清理及恶意软件卸载' }
    @{ Icon = '🛡️'; Text = '广告拦截服务'; Price = '10元/次'; Desc = '防止一刀999弹窗广告' }
)

foreach ($service in $services) {
    $serviceCard = New-Object System.Windows.Controls.Border
    $serviceCard.Background = '#FFFFFFFF'
    $serviceCard.BorderBrush = '#FFEDD4B0'
    $serviceCard.BorderThickness = 1
    $serviceCard.CornerRadius = 8
    $serviceCard.Padding = '10,8'
    $serviceCard.Margin = '0,0,0,6'
    
    $serviceInner = New-Object System.Windows.Controls.StackPanel
    
    # 服务名称行
    $serviceTitlePanel = New-Object System.Windows.Controls.StackPanel
    $serviceTitlePanel.Orientation = 'Horizontal'
    
    $serviceIcon = New-Object System.Windows.Controls.TextBlock
    $serviceIcon.Text = $service.Icon
    $serviceIcon.FontSize = 11
    $serviceIcon.Margin = '0,0,5,0'
    [void]$serviceTitlePanel.Children.Add($serviceIcon)
    
    $serviceName = New-Object System.Windows.Controls.TextBlock
    $serviceName.Text = $service.Text
    $serviceName.FontSize = 10
    $serviceName.FontWeight = 'SemiBold'
    $serviceName.Foreground = '#FF5D4E37'
    [void]$serviceTitlePanel.Children.Add($serviceName)
    
    [void]$serviceInner.Children.Add($serviceTitlePanel)
    
    # 服务描述
    $serviceDesc = New-Object System.Windows.Controls.TextBlock
    $serviceDesc.Text = $service.Desc
    $serviceDesc.FontSize = 8.5
    $serviceDesc.Foreground = '#FF95A5A6'
    $serviceDesc.Margin = '0,2,0,3'
    [void]$serviceInner.Children.Add($serviceDesc)
    
    # 价格标签
    $priceLabel = New-Object System.Windows.Controls.TextBlock
    $priceLabel.Text = $service.Price
    $priceLabel.FontSize = 9
    $priceLabel.FontWeight = 'Bold'
    $priceLabel.Foreground = '#FFFF6B9D'
    [void]$serviceInner.Children.Add($priceLabel)
    
    $serviceCard.Child = $serviceInner
    [void]$rightStack.Children.Add($serviceCard)
}

# 添加弹性空间
$spacer = New-Object System.Windows.Controls.Border
$spacer.Height = 1
$spacer.Background = 'Transparent'
$spacer.Margin = '0,10,0,10'
[void]$rightStack.Children.Add($spacer)

# 服务群标题
$groupTitle = New-Object System.Windows.Controls.TextBlock
$groupTitle.Text = '👥 加入服务群'  # 默认中文，语言切换时会更新
$groupTitle.FontSize = 13
$groupTitle.FontWeight = 'Bold'
$groupTitle.Foreground = '#FF6B4423'
$groupTitle.TextAlignment = 'Center'
$groupTitle.Margin = '0,0,0,10'
$script:groupTitle = $groupTitle
[void]$rightStack.Children.Add($groupTitle)

# QQ群二维码
$qqGroupBorder = New-Object System.Windows.Controls.Border
$qqGroupBorder.Width = 200
$qqGroupBorder.Height = 200
$qqGroupBorder.CornerRadius = 8
$qqGroupBorder.Background = 'White'
$qqGroupBorder.BorderBrush = '#FFEDD4B0'
$qqGroupBorder.BorderThickness = 1.5
$qqGroupBorder.Margin = '0,0,0,8'
$qqGroupBorder.HorizontalAlignment = 'Center'

$qqGroupImagePath = Join-Path $PSScriptRoot 'qq_group_qrcode.png'
if (Test-Path $qqGroupImagePath) {
    $qqGroupImage = New-Object System.Windows.Controls.Image
    $qqGroupImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([Uri]::new($qqGroupImagePath))
    $qqGroupImage.Stretch = 'Uniform'
    $qqGroupImage.Margin = '3'
    $qqGroupBorder.Child = $qqGroupImage
} else {
    # 如果图片不存在，显示提示文字
    $placeholderText = New-Object System.Windows.Controls.TextBlock
    $placeholderText.Text = '请将QQ群二维码保存为：' + "`n" + 'qq_group_qrcode.png' + "`n" + '并放置在dist文件夹中'
    $placeholderText.FontSize = 9
    $placeholderText.Foreground = '#FF95A5A6'
    $placeholderText.TextAlignment = 'Center'
    $placeholderText.VerticalAlignment = 'Center'
    $placeholderText.TextWrapping = 'Wrap'
    $placeholderText.Margin = '8'
    $qqGroupBorder.Child = $placeholderText
}

[void]$rightStack.Children.Add($qqGroupBorder)

# 群说明文字
$groupDesc = New-Object System.Windows.Controls.TextBlock
$groupDesc.Text = '扫码加入，获取技术支持'  # 默认中文，语言切换时会更新
$groupDesc.FontSize = 9
$groupDesc.Foreground = '#FF8B6F47'
$groupDesc.TextAlignment = 'Center'
$groupDesc.Margin = '0,0,0,0'
$script:groupDesc = $groupDesc
[void]$rightStack.Children.Add($groupDesc)

$rightPanel.Child = $rightStack

# ============ THEME SYSTEM ============
# Current theme index (0-4)
$script:currentTheme = 0

# Theme definitions - 5 BOLD & ARTISTIC themes
$script:themes = @(
    # Theme 0: Classic Warm (陶瓷风格 - 经典暖色)
    @{
        Name = 'Classic Warm'
        NameCN = '经典陶瓷'
        MainBg = @('#FFFFFBF5', '#FFFFFDF8', '#FFFFFEFB', '#FFFFFFFF')
        LeftPanelBg = @('#FFFFCC80', '#FFFFD090', '#FFFFD498', '#FFFFD8A0', '#FFFFDCA8')
        RightPanelBg = @('#FFFFF9F0', '#FFFFF5EB')
        GradientLayer = @('#FFFFDCA8', '#FFFFE4B8', '#FFFFECC8', '#FFFFF2D8', '#FFFFF6E5', '#FFFFFAEF', '#FFFFFDF8', '#FFFFFFFF')
        InputBg = @('#FFFFFFFE', '#FFFFFEFB', '#FFFFFDF8')
        InputBorder = '#FFEDD4B0'
        TextPrimary = '#FF6B4423'
        TextSecondary = '#FF8B6F47'
        TextTertiary = '#FF5D4E37'
        ButtonAboutBg = '#FFFFF5E6'
        ButtonAboutFg = '#FF8B6F47'
        ButtonAboutBorder = '#FFEDD4B0'
        ButtonLangBg = '#FFF0F8FF'
        ButtonLangFg = '#FF5B8DB8'
        ButtonLangBorder = '#FFBDD7EE'
        ButtonThemeBg = '#FFFEF5F5'
        ButtonThemeFg = '#FFBF6B7B'
        ButtonThemeBorder = '#FFE8C4CB'
        DonationBg = @('#FFD4A574', '#FFCF9A5D')
        ServiceCardBg = '#FFFFFFFF'
        ServiceCardBorder = '#FFEDD4B0'
        DialogBg = '#FFFFFFFF'
        DialogTitle = '#FF6B4423'
        DialogText = '#FF596066'
        DialogIcon = '#FFD4A574'
        DialogAccent = '#FFD37A00'
        DialogAccentFg = '#FFFFFFFF'
        DialogCancelBg = '#FFF8F9FA'
        DialogCancelFg = '#FF7F8C8D'
        DialogBorder = '#FFDFE4E8'
    },
    # Theme 1: 赛博朋克 🌃 - Cyberpunk (纯色扁平+霓虹描边)
    @{
        Name = 'Cyberpunk'
        NameCN = '赛博朋克'
        MainBg = @('#FF0A0E27')  # 纯深蓝黑背景
        LeftPanelBg = @('#FF1A1F3A')  # 纯色深蓝面板
        RightPanelBg = @('#FF0D1225')  # 纯色右侧
        GradientLayer = @('#FF1A1F3A', '#FF0A0E27')  # 最小渐变过渡
        InputBg = @('#FF0F1419')  # 纯黑输入框
        InputBorder = '#FF00F0FF'  # 霓虹青色边框
        TextPrimary = '#FF00F0FF'  # 霓虹青
        TextSecondary = '#FFFF00FF'  # 霓虹粉
        TextTertiary = '#FFFFFFFF'
        ButtonAboutBg = '#FF0F1419'
        ButtonAboutFg = '#FFFF00FF'
        ButtonAboutBorder = '#FFFF00FF'
        ButtonLangBg = '#FF0F1419'
        ButtonLangFg = '#FF00F0FF'
        ButtonLangBorder = '#FF00F0FF'
        ButtonThemeBg = '#FF0F1419'
        ButtonThemeFg = '#FFFFDD00'
        ButtonThemeBorder = '#FFFFDD00'
        DonationBg = @('#FFFF006E')  # 纯色按钮
        ServiceCardBg = '#FF0F1419'
        ServiceCardBorder = '#FFFF00FF'
        DialogBg = '#FF0A0E27'
        DialogTitle = '#FF00F0FF'
        DialogText = '#FFCED4DA'
        DialogIcon = '#FFFF00FF'
        DialogAccent = '#FFFF006E'
        DialogAccentFg = '#FFFFFFFF'
        DialogCancelBg = '#FF1A1F3A'
        DialogCancelFg = '#FFCED4DA'
        DialogBorder = '#FF00F0FF'
    },
    # Theme 2: 多彩拼接 🎨 - Colorful Blocks (多色块重叠)
    @{
        Name = 'Colorful'
        NameCN = '多彩拼接'
        MainBg = @('#FFF5F5F5')  # 浅灰白底
        LeftPanelBg = @('#FFFF6B6B', '#FFFF8E53', '#FFFFD93D', '#FF6BCF7F', '#FF4ECDC4')  # 彩虹色块
        RightPanelBg = @('#FFFFE5E5')  # 浅粉底
        GradientLayer = @('#FFFFFFFF', '#FFF5F5F5')  # 极简过渡
        InputBg = @('#FFFFFFFF')  # 纯白输入
        InputBorder = '#FFFF6B6B'  # 红色边框
        TextPrimary = '#FF2D3436'  # 深灰文字
        TextSecondary = '#FFFF6B6B'  # 红色强调
        TextTertiary = '#FF2D3436'
        ButtonAboutBg = '#FFFF6B6B'
        ButtonAboutFg = '#FFFFFFFF'
        ButtonAboutBorder = '#FFFF6B6B'
        ButtonLangBg = '#FF4ECDC4'
        ButtonLangFg = '#FFFFFFFF'
        ButtonLangBorder = '#FF4ECDC4'
        ButtonThemeBg = '#FFFFD93D'
        ButtonThemeFg = '#FF2D3436'
        ButtonThemeBorder = '#FFFFD93D'
        DonationBg = @('#FFFF8E53')  # 橙色纯色
        ServiceCardBg = '#FFFFFFFF'
        ServiceCardBorder = '#FF6BCF7F'
        DialogBg = '#FFFFFFFF'
        DialogTitle = '#FF2D3436'
        DialogText = '#FF636E72'
        DialogIcon = '#FFFF6B6B'
        DialogAccent = '#FFFF6B6B'
        DialogAccentFg = '#FFFFFFFF'
        DialogCancelBg = '#FFF5F5F5'
        DialogCancelFg = '#FF636E72'
        DialogBorder = '#FFDFE6E9'
    },
    # Theme 3: 玻璃态 💎 - Glassmorphism (毛玻璃+立体感)
    @{
        Name = 'Glass'
        NameCN = '玻璃态'
        MainBg = @('#FFFAFBFC')  # 极浅灰白
        LeftPanelBg = @('#E6FFFFFF')  # 半透明白（模拟毛玻璃）
        RightPanelBg = @('#E6F8F9FA')  # 半透明浅灰
        GradientLayer = @('#CCFFFFFF', '#00FFFFFF')  # 透明渐变
        InputBg = @('#F2FFFFFF')  # 半透明白输入框
        InputBorder = '#FF3B82F6'  # 蓝色边框
        TextPrimary = '#FF1E293B'  # 深灰蓝
        TextSecondary = '#FF64748B'  # 中灰
        TextTertiary = '#FF334155'
        ButtonAboutBg = '#E6FFFFFF'
        ButtonAboutFg = '#FF3B82F6'
        ButtonAboutBorder = '#FF3B82F6'
        ButtonLangBg = '#E6FFFFFF'
        ButtonLangFg = '#FF8B5CF6'
        ButtonLangBorder = '#FF8B5CF6'
        ButtonThemeBg = '#E6FFFFFF'
        ButtonThemeFg = '#FFEC4899'
        ButtonThemeBorder = '#FFEC4899'
        DonationBg = @('#FF3B82F6')  # 纯蓝色
        ServiceCardBg = '#F2FFFFFF'
        ServiceCardBorder = '#FFE2E8F0'
        DialogBg = '#FFFFFFFF'
        DialogTitle = '#FF1E293B'
        DialogText = '#FF475569'
        DialogIcon = '#FF3B82F6'
        DialogAccent = '#FF3B82F6'
        DialogAccentFg = '#FFFFFFFF'
        DialogCancelBg = '#FFF1F5F9'
        DialogCancelFg = '#FF64748B'
        DialogBorder = '#FFE2E8F0'
    },
    # Theme 4: 深色立体 🖤 - Dark Elevation (深色+阴影层次)
    @{
        Name = 'Dark'
        NameCN = '深色立体'
        MainBg = @('#FF121212')  # 纯黑底
        LeftPanelBg = @('#FF1E1E1E')  # 深灰面板
        RightPanelBg = @('#FF181818')  # 深灰右侧
        GradientLayer = @('#FF1E1E1E', '#FF121212')  # 最小过渡
        InputBg = @('#FF2C2C2C')  # 深灰输入框
        InputBorder = '#FFBB86FC'  # 紫色边框
        TextPrimary = '#FFFFFFFF'  # 纯白文字
        TextSecondary = '#FFBB86FC'  # 紫色强调
        TextTertiary = '#FFE0E0E0'
        ButtonAboutBg = '#FF2C2C2C'
        ButtonAboutFg = '#FFBB86FC'
        ButtonAboutBorder = '#FFBB86FC'
        ButtonLangBg = '#FF2C2C2C'
        ButtonLangFg = '#FF03DAC6'
        ButtonLangBorder = '#FF03DAC6'
        ButtonThemeBg = '#FF2C2C2C'
        ButtonThemeFg = '#FFCF6679'
        ButtonThemeBorder = '#FFCF6679'
        DonationBg = @('#FFBB86FC')  # 紫色纯色
        ServiceCardBg = '#FF2C2C2C'
        ServiceCardBorder = '#FF3C3C3C'
        DialogBg = '#FF1E1E1E'
        DialogTitle = '#FFFFFFFF'
        DialogText = '#FFB0B0B0'
        DialogIcon = '#FFBB86FC'
        DialogAccent = '#FFBB86FC'
        DialogAccentFg = '#FF000000'
        DialogCancelBg = '#FF2C2C2C'
        DialogCancelFg = '#FFB0B0B0'
        DialogBorder = '#FF3C3C3C'
    }
)

# Function to apply theme
function Apply-Theme {
    param([int]$ThemeIndex)
    
    if ($ThemeIndex -lt 0 -or $ThemeIndex -ge $script:themes.Count) { return }
    
    $theme = $script:themes[$ThemeIndex]
    $script:currentTheme = $ThemeIndex
    
    # Apply main border background
    if ($theme.MainBg.Count -eq 1) {
        # 纯色背景
        $mainBorder.Background = $theme.MainBg[0]
    } else {
        # 渐变背景
        $mainBorder.Background = New-Object System.Windows.Media.LinearGradientBrush
        $mainBorder.Background.StartPoint = '0,0.5'
        $mainBorder.Background.EndPoint = '1,0.5'
        for ($i = 0; $i -lt $theme.MainBg.Count; $i++) {
            $stop = New-Object System.Windows.Media.GradientStop
            $stop.Color = $theme.MainBg[$i]
            $stop.Offset = $i / ($theme.MainBg.Count - 1)
            $mainBorder.Background.GradientStops.Add($stop)
        }
    }
    
    # Apply left panel background
    if ($theme.LeftPanelBg.Count -eq 1) {
        $leftPanel.Background = $theme.LeftPanelBg[0]
    } else {
        $leftPanel.Background = New-Object System.Windows.Media.LinearGradientBrush
        $leftPanel.Background.StartPoint = '0,0'
        $leftPanel.Background.EndPoint = '0,1'
        for ($i = 0; $i -lt $theme.LeftPanelBg.Count; $i++) {
            $stop = New-Object System.Windows.Media.GradientStop
            $stop.Color = $theme.LeftPanelBg[$i]
            $stop.Offset = $i / ($theme.LeftPanelBg.Count - 1)
            $leftPanel.Background.GradientStops.Add($stop)
        }
    }
    
    # Apply right panel background
    if ($theme.RightPanelBg.Count -eq 1) {
        $rightPanel.Background = $theme.RightPanelBg[0]
    } else {
        $rightPanel.Background = New-Object System.Windows.Media.LinearGradientBrush
        $rightPanel.Background.StartPoint = '0,0'
        $rightPanel.Background.EndPoint = '0,1'
        for ($i = 0; $i -lt $theme.RightPanelBg.Count; $i++) {
            $stop = New-Object System.Windows.Media.GradientStop
            $stop.Color = $theme.RightPanelBg[$i]
            $stop.Offset = $i / ($theme.RightPanelBg.Count - 1)
            $rightPanel.Background.GradientStops.Add($stop)
        }
    }
    
    # Apply gradient layer
    if ($theme.GradientLayer.Count -eq 1) {
        $gradientLayer.Background = $theme.GradientLayer[0]
    } else {
        $gradientLayer.Background = New-Object System.Windows.Media.LinearGradientBrush
        $gradientLayer.Background.StartPoint = '0,0'
        $gradientLayer.Background.EndPoint = '1,0'
        for ($i = 0; $i -lt $theme.GradientLayer.Count; $i++) {
            $stop = New-Object System.Windows.Media.GradientStop
            $stop.Color = $theme.GradientLayer[$i]
            $stop.Offset = $i / ($theme.GradientLayer.Count - 1)
            $gradientLayer.Background.GradientStops.Add($stop)
        }
    }
    
    # Apply button colors
    $btnAbout.Background = $theme.ButtonAboutBg
    $btnAbout.Foreground = $theme.ButtonAboutFg
    $btnAbout.BorderBrush = $theme.ButtonAboutBorder
    
    $btnLanguage.Background = $theme.ButtonLangBg
    $btnLanguage.Foreground = $theme.ButtonLangFg
    $btnLanguage.BorderBrush = $theme.ButtonLangBorder
    
    $btnTheme.Background = $theme.ButtonThemeBg
    $btnTheme.Foreground = $theme.ButtonThemeFg
    $btnTheme.BorderBrush = $theme.ButtonThemeBorder
    
    # Apply text colors
    if ($script:schoolNameBlock) { $script:schoolNameBlock.Foreground = $theme.TextPrimary }
    $titleBlock.Foreground = $theme.TextTertiary
    $subtitleBlock.Foreground = $theme.TextSecondary
    
    # Apply donation button colors
    if ($script:donationBtn) {
        if ($theme.DonationBg.Count -eq 1) {
            $script:donationBtn.Background = $theme.DonationBg[0]
        } else {
            $donationBrush = New-Object System.Windows.Media.LinearGradientBrush
            $donationBrush.StartPoint = '0,0'
            $donationBrush.EndPoint = '1,1'
            for ($i = 0; $i -lt $theme.DonationBg.Count; $i++) {
                $stop = New-Object System.Windows.Media.GradientStop
                $stop.Color = $theme.DonationBg[$i]
                $stop.Offset = $i / ($theme.DonationBg.Count - 1)
                $donationBrush.GradientStops.Add($stop)
            }
            $script:donationBtn.Background = $donationBrush
        }
    }
    
    # Apply service card colors
    if ($script:groupTitle) { $script:groupTitle.Foreground = $theme.TextPrimary }
    if ($script:groupDesc) { $script:groupDesc.Foreground = $theme.TextSecondary }

    # Apply input groups (labels and borders)
    if ($script:inputGroups -and $script:inputGroups.Count -gt 0) {
        foreach ($g in $script:inputGroups) {
            try {
                if ($g.Label) { $g.Label.Foreground = $theme.TextSecondary }
                if ($g.Border) {
                    $g.Border.Background = $theme.InputBg[0]
                    $g.Border.BorderBrush = $theme.InputBorder
                }
            } catch {}
        }
    }
}

# ============ TOP TOOLBAR: About, Language, Theme ============
# Global language state
$script:isEnglish = $false

# Language text mappings
$script:texts = @{
    CN = @{
        StudentID = '学工号：'
        Password = '数字化(云陶)密码：'
        LoginDelay = '登录延迟：'
        ISP = '运营商：'
        WiFiSelection = 'Wi-Fi 选择：'
        SchoolNetwork = '学校网'
        CampusNetworkJCI = '校园网JCI'
        WiFiHint = '学校网包含 7 种网络；单连 JCI 速度更快'
        SignalThreshold = 'Wi-Fi信号低于百分值不连接：'
        Browser = '浏览器：'
        InfoText = '登录启动：输入密码后自动连接，不受快速启动影响。延迟范围：0-3秒，推荐1秒。'
        SecurityText = '🔒 安全提示：密码与学号已加密保存在本地电脑上，仅您的电脑可访问。'
        RemoveTask = '删除任务'
        SaveConfig = '保存配置'
        SaveAndConnect = '保存并连接'
        Exit = '退出'
        UnicomISP = '中国联通'
        TelecomISP = '中国电信'
        CmccISP = '中国移动'
        NoneISP = '无'
        Second = '秒'
        # Donation dialog
        DonationTitle = '☕ 请作者喝咖啡'
        DonationMessage = '如果小瓷帮到了你，可以请小瓷喝杯奶茶哦~ 💕'
        DonationThanks = '感谢你的支持，这是对小瓷最大的鼓励！❤️'
        DonationClose = '关闭'
        DonationAuthorNotice = '注意：作者名为：*青'
        SchoolName = '景德镇陶瓷大学'
        DonationBtnText = '☕ 请作者喝咖啡'
        ServiceGroupTitle = '👥 加入服务群'
        ServiceGroupHint = '扫码加入，获取技术支持'
        # Confirmation dialogs
        ConfirmRemoveTitle = '确认删除'
        ConfirmRemoveMessage = "确认要删除自动启动任务吗？`n`n此操作将：`n• 删除登录自动连接任务`n• 清理程序配置和数据`n`n删除后需要重新配置程序。"
        RemoveSuccessTitle = '卸载成功'
        RemoveSuccessMessage = "程序已卸载。`n`n✅ 自动启动任务已删除`n✅ 配置和凭据已清理`n`n如需重新使用，请重新运行程序。"
        RemovePartialTitle = '部分成功'
        RemovePartialMessage = "任务已删除。`n`n✅ 自动启动任务已删除`n⚠️ 部分数据清理失败`n`n如需重新使用，请重新运行程序。"
        RemoveFailTitle = '删除失败'
        TaskNotFoundTitle = '提示'
        TaskNotFoundMessage = '当前系统中未找到自动启动任务。'
        SaveSuccessTitle = '配置已保存'
        SaveSuccessMessage = "登录启动任务已创建（延迟 {0} 秒）`n`n配置信息已成功保存。"
        SaveAndConnectTitle = '操作成功'
        SaveAndConnectMessage = "配置已保存并创建登录启动任务（延迟 {0} 秒）`n`n正在连接校园网络..."
        WechatCopySuccess = '微信号已复制到剪贴板！'
        WechatCopyFail = '复制失败，请手动复制：HelloAiEngine'
        CopySuccessTitle = '复制成功'
        ErrorTitle = '错误'
        PermissionErrorTitle = '权限错误'
        PermissionErrorMessage = '权限不足：请以管理员身份运行本程序。'
        ConfigNotFoundError = '配置文件未找到：{0}'
        ConfigFormatError = '配置文件格式错误：{0}'
        ConfigInvalidError = '配置文件内容无效，请检查配置文件。'
        ConfigSaveError = '保存配置文件失败：{0}'
        # About dialog
        AboutTitle = '🌸 关于小瓷连网'
        AboutVersion = '版本 1.0.0'
        AboutUsageTitle = '📋 使用说明'
        AboutUsageContent = @"
本工具会收集以下匿名信息用于改进服务：

✅ 我们收集的信息：
  • 匿名设备标识（无法关联到个人）
  • 程序版本号
  • 使用时间统计
  • 操作系统版本

❌ 我们不会收集：
  • 用户名、密码
  • 上网记录
  • 任何个人身份信息
  • IP地址或位置信息

🔒 数据安全承诺：
  • 所有数据完全匿名化
  • 仅用于统计分析和改进工具
  • 不会与第三方分享
  • 数据保留期限：3个月

💡 更新检查：
  • 自动检查新版本
  • 发现更新时会提醒您
  • 您可以自主选择是否更新
"@
        AboutCopyright = '© 2025 小瓷连网 - 让连网更简单'
        AboutCloseBtn = '我知道了'
        # Quick start guide
        QuickGuideTitle = '💡 快速使用指南'
        QuickGuideContent = @"
🎯 主要功能：
• 自动连接校园网络
• 开机登录后自动认证
• 多网络智能选择

⚙️ 参数说明：
• 学工号/密码：校园网登录凭据
• 登录延迟：开机后延迟连接时间（0-3秒）
• 运营商：选择网络运营商类型
• Wi-Fi选择：
  - 学校网：自动连接7种网络（推荐）
  - 校园网JCI：仅连接JCI网络（连接更快）
• 信号阈值：低于此信号强度不连接
• 浏览器：用于网页认证的浏览器

📢 重要提示：
✅ 没有购买校园网也能使用本工具！
✅ 可以使用学校的免费网络（食堂、图书馆等）
⚠️ 未购买校园网在寝室可能连不上网络
✅ 但不影响在其他区域正常使用

👉 右侧：远程支持、加入QQ群获取帮助
"@
        QuickGuideCloseBtn = '开始使用'
    }
    EN = @{
        StudentID = 'Student ID:'
        Password = 'Digital (Cloud) Password:'
        LoginDelay = 'Login Delay:'
        ISP = 'ISP:'
        WiFiSelection = 'Wi-Fi Selection:'
        SchoolNetwork = 'School Net'
        CampusNetworkJCI = 'Campus Net JCI'
        WiFiHint = 'School Net includes 7 networks; single JCI is faster'
        SignalThreshold = 'Wi-Fi signal below percentage not connect:'
        Browser = 'Browser:'
        InfoText = 'Login startup: Automatically connects after entering password, not affected by fast startup. Delay range: 0-3 seconds, recommended 1 second.'
        SecurityText = '🔒 Security: Password and student ID are encrypted and stored on your local computer, only accessible to your computer.'
        RemoveTask = 'Remove Task'
        SaveConfig = 'Save Config'
        SaveAndConnect = 'Save & Connect'
        Exit = 'Exit'
        UnicomISP = 'China Unicom'
        TelecomISP = 'China Telecom'
        CmccISP = 'China Mobile'
        NoneISP = 'None'
        Second = 's'
        # Donation dialog
        DonationTitle = '☕ Buy Me a Coffee'
        DonationMessage = 'If XiaoCi helped you, you can buy me a cup of milk tea~ 💕'
        DonationThanks = 'Thank you for your support, it''s the greatest encouragement to XiaoCi! ❤️'
        DonationClose = 'Close'
        DonationAuthorNotice = 'Note: Author name is: *Qing'
        SchoolName = 'Jingdezhen Ceramic University'
        DonationBtnText = '💝 Tip the Author'
        ServiceGroupTitle = '👥 Join Service Group'
        ServiceGroupHint = 'Scan to join and get technical support'
        # Confirmation dialogs
        ConfirmRemoveTitle = 'Confirm Removal'
        ConfirmRemoveMessage = "Are you sure you want to remove the auto-start task?`n`nThis will:`n• Remove login auto-connect task`n• Clear program configuration and data`n`nYou will need to reconfigure the program after removal."
        RemoveSuccessTitle = 'Uninstall Successful'
        RemoveSuccessMessage = "Program uninstalled.`n`n✅ Auto-start task removed`n✅ Configuration and credentials cleared`n`nTo use again, please rerun the program."
        RemovePartialTitle = 'Partial Success'
        RemovePartialMessage = "Task removed.`n`n✅ Auto-start task removed`n⚠️ Some data cleanup failed`n`nTo use again, please rerun the program."
        RemoveFailTitle = 'Removal Failed'
        TaskNotFoundTitle = 'Notice'
        TaskNotFoundMessage = 'Auto-start task not found in the current system.'
        SaveSuccessTitle = 'Configuration Saved'
        SaveSuccessMessage = "Login startup task created (delay {0} seconds)`n`nConfiguration saved successfully."
        SaveAndConnectTitle = 'Operation Successful'
        SaveAndConnectMessage = "Configuration saved and login startup task created (delay {0} seconds)`n`nConnecting to campus network..."
        WechatCopySuccess = 'WeChat ID copied to clipboard!'
        WechatCopyFail = 'Copy failed, please copy manually: HelloAiEngine'
        CopySuccessTitle = 'Copy Successful'
        ErrorTitle = 'Error'
        PermissionErrorTitle = 'Permission Error'
        PermissionErrorMessage = 'Insufficient permissions: Please run this program as administrator.'
        ConfigNotFoundError = 'Configuration file not found: {0}'
        ConfigFormatError = 'Configuration file format error: {0}'
        ConfigInvalidError = 'Configuration file content is invalid, please check the configuration file.'
        ConfigSaveError = 'Failed to save configuration file: {0}'
        # About dialog
        AboutTitle = '🌸 About XiaoCi Network'
        AboutVersion = 'Version 1.0.0'
        AboutUsageTitle = '📋 User Guide'
        AboutUsageContent = @"
This tool collects the following anonymous information to improve service:

✅ Information we collect:
  • Anonymous device identifier (cannot be linked to individuals)
  • Program version number
  • Usage time statistics
  • Operating system version

❌ We do NOT collect:
  • Username, password
  • Browsing history
  • Any personal identification information
  • IP address or location information

🔒 Data Security Commitment:
  • All data is completely anonymous
  • Only used for statistical analysis and tool improvement
  • Will not be shared with third parties
  • Data retention period: 3 months

💡 Update Check:
  • Automatically check for new versions
  • Notify you when updates are found
  • You can choose whether to update
"@
        AboutCopyright = '© 2025 XiaoCi Network - Making Connection Easier'
        AboutCloseBtn = 'I Understand'
        # Quick start guide
        QuickGuideTitle = '💡 Quick Start Guide'
        QuickGuideContent = @"
🎯 Main Features:
• Auto-connect to campus network
• Auto-authenticate after login
• Smart multi-network selection

⚙️ Parameters:
• Student ID/Password: Campus network credentials
• Login Delay: Delay time after boot (0-3 seconds)
• ISP: Select network operator type
• Wi-Fi Selection:
  - School Net: Connect 7 networks (recommended)
  - Campus Net JCI: Only JCI (faster connection)
• Signal Threshold: Don't connect below this signal
• Browser: Browser for web authentication

📢 Important Notice:
✅ You can use this tool WITHOUT purchasing campus internet!
✅ Use school's free networks (cafeteria, library, etc.)
⚠️ May not connect in dorm without paid campus internet
✅ Works normally in other areas

👉 Right side: Remote support, Join QQ group for help
"@
        QuickGuideCloseBtn = 'Get Started'
    }
}

# Function to switch language
function Switch-Language {
    $script:isEnglish = -not $script:isEnglish
    $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
    
    # Update button texts
    if ($script:btnLanguage) { $script:btnLanguage.Content = if ($script:isEnglish) { '🌐 中文' } else { '🌐 EN' } }
    if ($script:btnTheme) { $script:btnTheme.Content = if ($script:isEnglish) { '🎨 Theme' } else { '🎨 主题' } }
    
    # Update all UI element labels
    foreach ($key in $script:uiElements.Keys) {
        $element = $script:uiElements[$key]
        $text = $script:texts[$lang][$key]
        if ($element.Icon) {
            $element.Control.Text = "$($element.Icon)  $text"
        } else {
            $element.Control.Text = $text
        }
    }
    
    # Update standalone text elements
    if ($script:infoText) {
        $script:infoText.Text = $script:texts[$lang].InfoText
    }
    if ($script:secText) {
        $script:secText.Text = $script:texts[$lang].SecurityText
    }
    if ($script:wifiHintText) {
        $script:wifiHintText.Text = $script:texts[$lang].WiFiHint
    }
    
    # Update buttons
    if ($script:BtnRemoveTask) {
        $script:BtnRemoveTask.Content = $script:texts[$lang].RemoveTask
    }
    if ($script:BtnSave) {
        $script:BtnSave.Content = $script:texts[$lang].SaveConfig
    }
    if ($script:BtnSaveRun) {
        $script:BtnSaveRun.Content = $script:texts[$lang].SaveAndConnect
    }
    if ($script:BtnExit) {
        $script:BtnExit.Content = $script:texts[$lang].Exit
    }
    
    # Update radio buttons
    if ($script:RbAuto) {
        $script:RbAuto.Content = $script:texts[$lang].SchoolNetwork
    }
    if ($script:RbJCI) {
        $script:RbJCI.Content = $script:texts[$lang].CampusNetworkJCI
    }
    
    # Update ISP combo box
    if ($script:CmbISP) {
        $savedIndex = $script:CmbISP.SelectedIndex
        $script:CmbISP.Items.Clear()
        foreach($t in @($script:texts[$lang].UnicomISP, $script:texts[$lang].TelecomISP, $script:texts[$lang].CmccISP, $script:texts[$lang].NoneISP)) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = $t
            [void]$script:CmbISP.Items.Add($item)
        }
        $script:CmbISP.SelectedIndex = $savedIndex
    }
    
    # Update delay label
    if ($script:SldDelay -and $script:LblDelay) {
        $script:LblDelay.Text = ([Math]::Round($script:SldDelay.Value, 0)).ToString('0') + $script:texts[$lang].Second
    }
    
    # Update school name
    if ($script:schoolNameBlock) {
        $script:schoolNameBlock.Text = $script:texts[$lang].SchoolName
    }
    
    # Update donation button
    if ($script:donationBtn) {
        $script:donationBtn.Content = $script:texts[$lang].DonationBtnText
    }
    
    # Update service group title and hint
    if ($script:groupTitle) {
        $script:groupTitle.Text = $script:texts[$lang].ServiceGroupTitle
    }
    if ($script:groupDesc) {
        $script:groupDesc.Text = $script:texts[$lang].ServiceGroupHint
    }
}

$topToolbar = New-Object System.Windows.Controls.StackPanel
$topToolbar.Orientation = 'Horizontal'
$topToolbar.HorizontalAlignment = 'Left'
$topToolbar.VerticalAlignment = 'Top'
$topToolbar.Margin = '15,15,0,0'
[System.Windows.Controls.Panel]::SetZIndex($topToolbar, 100)

# About button
$btnAbout = New-Object System.Windows.Controls.Button
$script:btnAbout = $btnAbout
$btnAbout.Content = 'ℹ'  # 使用更优雅的信息图标
$btnAbout.Height = 36
$btnAbout.Width = 36
$btnAbout.FontSize = 20
$btnAbout.Margin = '0,0,10,0'
$btnAbout.Background = '#FFFFF5E6'
$btnAbout.Foreground = '#FF8B6F47'
$btnAbout.BorderBrush = '#FFEDD4B0'
$btnAbout.BorderThickness = 1.5
$btnAbout.Cursor = 'Hand'
$btnAbout.FontWeight = 'Medium'
$aboutTemplate = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <Border Background="{TemplateBinding Background}" 
            BorderBrush="{TemplateBinding BorderBrush}" 
            BorderThickness="{TemplateBinding BorderThickness}" 
            CornerRadius="8">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
</ControlTemplate>
"@
$btnAbout.Template = [System.Windows.Markup.XamlReader]::Parse($aboutTemplate)
$btnAbout.Add_Click({
    Show-AboutDialog
})
[void]$topToolbar.Children.Add($btnAbout)

# Language button
$btnLanguage = New-Object System.Windows.Controls.Button
$script:btnLanguage = $btnLanguage
$btnLanguage.Content = '🌐 EN'  # 添加地球图标
$btnLanguage.Height = 36
$btnLanguage.Padding = '12,6'
$btnLanguage.FontSize = 11
$btnLanguage.Margin = '0,0,10,0'
$btnLanguage.Background = '#FFF0F8FF'
$btnLanguage.Foreground = '#FF5B8DB8'
$btnLanguage.BorderBrush = '#FFBDD7EE'
$btnLanguage.BorderThickness = 1.5
$btnLanguage.Cursor = 'Hand'
$btnLanguage.FontWeight = 'Medium'
$btnLanguage.Template = [System.Windows.Markup.XamlReader]::Parse($aboutTemplate)
$btnLanguage.Add_Click({
    Switch-Language
})
[void]$topToolbar.Children.Add($btnLanguage)

# Theme button
$btnTheme = New-Object System.Windows.Controls.Button
$script:btnTheme = $btnTheme
$btnTheme.Content = '🎨 主题'  # 添加调色板图标
$btnTheme.Height = 36
$btnTheme.Padding = '12,6'
$btnTheme.FontSize = 11
$btnTheme.Margin = '0,0,10,0'
$btnTheme.Background = '#FFFEF5F5'
$btnTheme.Foreground = '#FFBF6B7B'
$btnTheme.BorderBrush = '#FFE8C4CB'
$btnTheme.BorderThickness = 1.5
$btnTheme.Cursor = 'Hand'
$btnTheme.FontWeight = 'Medium'
$btnTheme.Template = [System.Windows.Markup.XamlReader]::Parse($aboutTemplate)
$btnTheme.Add_Click({
    # 循环切换主题
    $script:currentTheme = ($script:currentTheme + 1) % $script:themes.Count
    Apply-Theme -ThemeIndex $script:currentTheme
    # 更新按钮文本，不显示主题名称
    if ($script:btnTheme) { $script:btnTheme.Content = if ($script:isEnglish) { '🎨 Theme' } else { '🎨 主题' } }
})
[void]$topToolbar.Children.Add($btnTheme)

[void]$grid.Children.Add($topToolbar)

# Window control buttons at top right (minimize, maximize, close)
$windowButtonsPanel = New-Object System.Windows.Controls.StackPanel
$windowButtonsPanel.Orientation = 'Horizontal'
$windowButtonsPanel.HorizontalAlignment = 'Right'
$windowButtonsPanel.VerticalAlignment = 'Top'
$windowButtonsPanel.Margin = '0,15,15,0'
[System.Windows.Controls.Panel]::SetZIndex($windowButtonsPanel, 100)

# Minimize button with avatar
$minimizeBorder = New-Object System.Windows.Controls.Border
$minimizeBorder.Width = 36
$minimizeBorder.Height = 36
$minimizeBorder.CornerRadius = 18
$minimizeBorder.Margin = '5,0,0,0'
$minimizeBorder.Cursor = 'Hand'
$minimizeBorder.ClipToBounds = $true
$minimizeBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
$minimizeBorder.Effect.BlurRadius = 8
$minimizeBorder.Effect.ShadowDepth = 2
$minimizeBorder.Effect.Opacity = 0.3
$minimizeBorder.Effect.Color = '#FF000000'

$minimizeImagePath = Join-Path $PSScriptRoot 'minimize_avatar.png'
if (Test-Path $minimizeImagePath) {
    $minimizeImage = New-Object System.Windows.Controls.Image
    $minimizeImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([Uri]::new($minimizeImagePath))
    $minimizeImage.Stretch = 'UniformToFill'
    # Apply circular clip geometry
    $minimizeImage.Clip = New-Object System.Windows.Media.EllipseGeometry -Property @{
        Center = New-Object System.Windows.Point(18, 18)
        RadiusX = 18
        RadiusY = 18
    }
    $minimizeBorder.Child = $minimizeImage
} else {
    # Fallback to text if image not found
    $minimizeBorder.Background = '#FF95A5A6'
$minimizeText = New-Object System.Windows.Controls.TextBlock
$minimizeText.Text = '—'
$minimizeText.FontSize = 18
$minimizeText.FontWeight = 'Bold'
$minimizeText.Foreground = '#FFFFFFFF'
$minimizeText.HorizontalAlignment = 'Center'
$minimizeText.VerticalAlignment = 'Center'
$minimizeBorder.Child = $minimizeText
}
$minimizeBorder.Add_MouseLeftButtonDown({
    param($s, $e)
    $e.Handled = $true
    $window.WindowState = 'Minimized'
})
[void]$windowButtonsPanel.Children.Add($minimizeBorder)

# Maximize/Restore button with avatar
$maximizeBorder = New-Object System.Windows.Controls.Border
$maximizeBorder.Width = 36
$maximizeBorder.Height = 36
$maximizeBorder.CornerRadius = 18
$maximizeBorder.Margin = '5,0,0,0'
$maximizeBorder.Cursor = 'Hand'
$maximizeBorder.ClipToBounds = $true
$maximizeBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
$maximizeBorder.Effect.BlurRadius = 8
$maximizeBorder.Effect.ShadowDepth = 2
$maximizeBorder.Effect.Opacity = 0.3
$maximizeBorder.Effect.Color = '#FF000000'

$maximizeImagePath = Join-Path $PSScriptRoot 'maximize_avatar.png'
if (Test-Path $maximizeImagePath) {
    $maximizeImage = New-Object System.Windows.Controls.Image
    $maximizeImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([Uri]::new($maximizeImagePath))
    $maximizeImage.Stretch = 'UniformToFill'
    # Apply circular clip geometry
    $maximizeImage.Clip = New-Object System.Windows.Media.EllipseGeometry -Property @{
        Center = New-Object System.Windows.Point(18, 18)
        RadiusX = 18
        RadiusY = 18
    }
    $maximizeBorder.Child = $maximizeImage
} else {
    # Fallback to text if image not found
    $maximizeBorder.Background = '#FF52A5F9'
$maximizeText = New-Object System.Windows.Controls.TextBlock
$maximizeText.Text = '□'
$maximizeText.FontSize = 18
$maximizeText.FontWeight = 'Bold'
$maximizeText.Foreground = '#FFFFFFFF'
$maximizeText.HorizontalAlignment = 'Center'
$maximizeText.VerticalAlignment = 'Center'
$maximizeBorder.Child = $maximizeText
}
$maximizeBorder.Add_MouseLeftButtonDown({
    param($s, $e)
    $e.Handled = $true
    if ($window.WindowState -eq 'Maximized') {
        $window.WindowState = 'Normal'
    } else {
        $window.WindowState = 'Maximized'
    }
})
[void]$windowButtonsPanel.Children.Add($maximizeBorder)

# Close button with avatar
$closeBorder = New-Object System.Windows.Controls.Border
$closeBorder.Width = 36
$closeBorder.Height = 36
$closeBorder.CornerRadius = 18
$closeBorder.Margin = '5,0,0,0'
$closeBorder.Cursor = 'Hand'
$closeBorder.ClipToBounds = $true
$closeBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
$closeBorder.Effect.BlurRadius = 8
$closeBorder.Effect.ShadowDepth = 2
$closeBorder.Effect.Opacity = 0.3
$closeBorder.Effect.Color = '#FFFF0000'

$closeImagePath = Join-Path $PSScriptRoot 'close_avatar.png'
if (Test-Path $closeImagePath) {
    $closeImage = New-Object System.Windows.Controls.Image
    $closeImage.Source = [System.Windows.Media.Imaging.BitmapImage]::new([Uri]::new($closeImagePath))
    $closeImage.Stretch = 'UniformToFill'
    # Apply circular clip geometry
    $closeImage.Clip = New-Object System.Windows.Media.EllipseGeometry -Property @{
        Center = New-Object System.Windows.Point(18, 18)
        RadiusX = 18
        RadiusY = 18
    }
    $closeBorder.Child = $closeImage
} else {
    # Fallback to text if image not found
    $closeBorder.Background = '#FFFF6B6B'
$closeText = New-Object System.Windows.Controls.TextBlock
$closeText.Text = '×'
$closeText.FontSize = 20
$closeText.FontWeight = 'Bold'
$closeText.Foreground = '#FFFFFFFF'
$closeText.HorizontalAlignment = 'Center'
$closeText.VerticalAlignment = 'Center'
$closeBorder.Child = $closeText
}
$closeBorder.Add_MouseLeftButtonDown({
    param($s, $e)
    $e.Handled = $true
    $window.Close()
})
[void]$windowButtonsPanel.Children.Add($closeBorder)

# Make the window buttons span all columns and align to the right
[System.Windows.Controls.Grid]::SetColumnSpan($windowButtonsPanel, 3)
[void]$grid.Children.Add($windowButtonsPanel)

# Content scroll viewer
$scrollViewer = New-Object System.Windows.Controls.ScrollViewer
$scrollViewer.VerticalScrollBarVisibility = 'Hidden'
$scrollViewer.Margin = '30,55,30,20'
[void]$middlePanel.Children.Add($scrollViewer)

# Content stack panel
$contentStack = New-Object System.Windows.Controls.StackPanel
$contentStack.Margin = '0'

# Store all UI elements that need language updates
$script:uiElements = @{}
$script:inputGroups = @()

# Helper function to create styled input container
function New-InputGroup {
    param([string]$Label, $Control, [string]$Icon = '', [string]$LabelKey = '')
    
    $container = New-Object System.Windows.Controls.StackPanel
    $container.Margin = '0,0,0,10'
    
    $labelBlock = New-Object System.Windows.Controls.TextBlock
    $labelText = if ($Icon) { "$Icon  $Label" } else { $Label }
    $labelBlock.Text = $labelText
    $labelBlock.FontSize = 12
    $labelBlock.Foreground = ($script:themes[$script:currentTheme]).TextSecondary
    $labelBlock.Margin = '0,0,0,6'
    $labelBlock.FontWeight = 'SemiBold'
    
    # Store label for language switching
    if ($LabelKey) {
        $script:uiElements[$LabelKey] = @{ Control = $labelBlock; Icon = $Icon }
    }
    
    [void]$container.Children.Add($labelBlock)
    
    $controlBorder = New-Object System.Windows.Controls.Border
    # 使用主题的纯色输入背景，避免全局过度渐变
    $controlBorder.Background = ($script:themes[$script:currentTheme]).InputBg[0]
    
    $controlBorder.BorderBrush = ($script:themes[$script:currentTheme]).InputBorder
    $controlBorder.BorderThickness = 1.5
    $controlBorder.CornerRadius = 12
    $controlBorder.Padding = '14,9'
    $controlBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $controlBorder.Effect.BlurRadius = 8
    $controlBorder.Effect.ShadowDepth = 2
    $controlBorder.Effect.Opacity = 0.08
    $controlBorder.Effect.Color = '#FFCCA060'
    $controlBorder.Child = $Control
    [void]$container.Children.Add($controlBorder)
    
    $script:inputGroups += @{
        Label = $labelBlock
        Border = $controlBorder
        Control = $Control
    }
    
    return $container
}

# School name title
$schoolNameBlock = New-Object System.Windows.Controls.TextBlock
$schoolNameBlock.Text = (CS @(0x666F,0x5FB7,0x9547,0x9676,0x74F7,0x5927,0x5B66))  # 景德镇陶瓷大学，语言切换时会更新
$schoolNameBlock.FontSize = 18
$schoolNameBlock.FontWeight = 'Bold'
$schoolNameBlock.Foreground = '#FF6B4423'
$schoolNameBlock.TextAlignment = 'Center'
$schoolNameBlock.Margin = '0,0,0,20'
$script:schoolNameBlock = $schoolNameBlock
[void]$contentStack.Children.Add($schoolNameBlock)

# Username
$TxtUser = New-Object System.Windows.Controls.TextBox
$TxtUser.FontSize = 13.5
$TxtUser.BorderThickness = 0
$TxtUser.Background = 'Transparent'
$TxtUser.Foreground = '#FF5D4E37'
$TxtUser.FontWeight = 'Medium'
$TxtUser.CaretBrush = '#FFCCA060'
[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x5B66,0x5DE5,0x53F7,0xFF1A))) -Control $TxtUser -LabelKey 'StudentID'))

# Password
$PwdBox = New-Object System.Windows.Controls.PasswordBox
$PwdBox.FontSize = 13.5
$PwdBox.BorderThickness = 0
$PwdBox.Background = 'Transparent'
$PwdBox.Foreground = '#FF5D4E37'
$PwdBox.FontWeight = 'Medium'
[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x6570,0x5B57,0x5316,0x0028,0x4E91,0x9676,0x0029,0x5BC6,0x7801,0xFF1A))) -Control $PwdBox -LabelKey 'Password'))

# Delay slider
$delayContainer = New-Object System.Windows.Controls.StackPanel
$delayInner = New-Object System.Windows.Controls.StackPanel
$delayInner.Orientation = 'Horizontal'
$SldDelay = New-Object System.Windows.Controls.Slider
$SldDelay.Minimum = 0
$SldDelay.Maximum = 3
$SldDelay.Value = 1
$SldDelay.Width = 180
$SldDelay.TickFrequency = 1
$SldDelay.IsSnapToTickEnabled = $true
$SldDelay.Foreground = '#FFCCA060'
$SldDelay.VerticalAlignment = 'Center'
$LblDelay = New-Object System.Windows.Controls.TextBlock
$LblDelay.Text = '1' + (CS @(0x79D2))
$LblDelay.Margin = '16,0,0,0'
$LblDelay.FontSize = 14
$LblDelay.FontWeight = 'Bold'
$LblDelay.Foreground = '#FFD4A574'
$LblDelay.VerticalAlignment = 'Center'
$script:SldDelay = $SldDelay
$script:LblDelay = $LblDelay
$SldDelay.add_ValueChanged({ 
    try { 
        $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
        $script:LblDelay.Text = ([Math]::Round($script:SldDelay.Value, 0)).ToString('0') + $script:texts[$lang].Second 
    } catch {} 
})
[void]$delayInner.Children.Add($SldDelay)
[void]$delayInner.Children.Add($LblDelay)
$delayContainer.Children.Add((New-InputGroup -Label ((CS @(0x767B,0x5F55,0x5EF6,0x8FDF,0xFF1A))) -Control $delayInner -LabelKey 'LoginDelay'))
[void]$contentStack.Children.Add($delayContainer)

# ISP Combo
$CmbISP = New-Object System.Windows.Controls.ComboBox
$script:CmbISP = $CmbISP
$CmbISP.FontSize = 13.5
$CmbISP.BorderThickness = 0
$CmbISP.Background = 'Transparent'
$CmbISP.Foreground = '#FF5D4E37'
$CmbISP.FontWeight = 'Medium'
foreach($t in @((CS @(0x4E2D,0x56FD,0x8054,0x901A)),(CS @(0x4E2D,0x56FD,0x7535,0x4FE1)),(CS @(0x4E2D,0x56FD,0x79FB,0x52A8)),(CS @(0x65E0)))) {
    $item = New-Object System.Windows.Controls.ComboBoxItem
    $item.Content = $t
    [void]$CmbISP.Items.Add($item)
}
[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x8FD0,0x8425,0x5546,0xFF1A))) -Control $CmbISP -LabelKey 'ISP'))

# Wi-Fi selection
$wifiPanel = New-Object System.Windows.Controls.StackPanel
$wifiPanel.Orientation = 'Horizontal'
$RbAuto = New-Object System.Windows.Controls.RadioButton
$script:RbAuto = $RbAuto
$RbAuto.Content = (CS @(0x5B66,0x6821,0x7F51))
$RbAuto.IsChecked = $true
$RbAuto.Margin = '0,0,30,0'
$RbAuto.FontSize = 13
$RbAuto.Foreground = '#FF5D4E37'
$RbAuto.FontWeight = 'Medium'
$RbJCI = New-Object System.Windows.Controls.RadioButton
$script:RbJCI = $RbJCI
$RbJCI.Content = (CS @(0x6821,0x56ED,0x7F51,0x004A,0x0043,0x0049))
$RbJCI.FontSize = 13
$RbJCI.Foreground = '#FF5D4E37'
$RbJCI.FontWeight = 'Medium'
[void]$wifiPanel.Children.Add($RbAuto)
[void]$wifiPanel.Children.Add($RbJCI)

# Add WiFi hint text
$wifiHintText = New-Object System.Windows.Controls.TextBlock
$script:wifiHintText = $wifiHintText
$wifiHintText.Text = (CS @(0x5B66,0x6821,0x7F51,0x5305,0x542B,0x6821,0x56ED,0x7F51,0xFF1B,0x5355,0x8FDE,0x6821,0x56ED,0x7F51,0x901F,0x5EA6,0x66F4,0x5FEB))
$wifiHintText.FontSize = 10.5
$wifiHintText.Foreground = '#FF8B9DC3'
$wifiHintText.Margin = '0,8,0,0'
$wifiHintText.FontStyle = 'Italic'
$wifiHintText.Opacity = 0.85
[void]$wifiPanel.Children.Add($wifiHintText)

[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x0057,0x0069,0x002D,0x0046,0x0069,0x0020,0x9009,0x62E9,0xFF1A))) -Control $wifiPanel -LabelKey 'WiFiSelection'))

# Signal slider
$signalInner = New-Object System.Windows.Controls.StackPanel
$signalInner.Orientation = 'Horizontal'
$SldSignal = New-Object System.Windows.Controls.Slider
$SldSignal.Minimum = 10
$SldSignal.Maximum = 80
$SldSignal.Value = 30
$SldSignal.Width = 180
$SldSignal.TickFrequency = 5
$SldSignal.IsSnapToTickEnabled = $true
$SldSignal.Foreground = '#FF9ACD78'
$LblSignal = New-Object System.Windows.Controls.TextBlock
$LblSignal.Text = '30%'
$LblSignal.Margin = '16,0,0,0'
$LblSignal.FontSize = 14
$LblSignal.FontWeight = 'Bold'
$LblSignal.Foreground = '#FF7DAA5A'
$SldSignal.add_ValueChanged({ try { $LblSignal.Text = ([int]$SldSignal.Value).ToString() + '%' } catch {} })
[void]$signalInner.Children.Add($SldSignal)
[void]$signalInner.Children.Add($LblSignal)
[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x0057,0x0069,0x002D,0x0046,0x0069,0x4FE1,0x53F7,0x4F4E,0x4E8E,0x767E,0x5206,0x503C,0x4E0D,0x8FDE,0x63A5,0xFF1A))) -Control $signalInner -LabelKey 'SignalThreshold'))

# Browser combo
$CmbBrowser = New-Object System.Windows.Controls.ComboBox
$CmbBrowser.FontSize = 13.5
$CmbBrowser.BorderThickness = 0
$CmbBrowser.Background = 'Transparent'
$CmbBrowser.Foreground = '#FF5D4E37'
$CmbBrowser.FontWeight = 'Medium'
foreach($t in @('edge','chrome')) {
    $item = New-Object System.Windows.Controls.ComboBoxItem
    $item.Content = $t
    [void]$CmbBrowser.Items.Add($item)
}
[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x6D4F,0x89C8,0x5668,0xFF1A))) -Control $CmbBrowser -LabelKey 'Browser'))

# Info text
$infoText = New-Object System.Windows.Controls.TextBlock
$script:infoText = $infoText
$infoText.Text = (CS @(0x767B,0x5F55,0x542F,0x52A8,0xFF1A,0x8F93,0x5165,0x5BC6,0x7801,0x540E,0x81EA,0x52A8,0x8FDE,0x63A5,0xFF0C,0x4E0D,0x53D7,0x5FEB,0x901F,0x542F,0x52A8,0x5F71,0x54CD,0x3002,0x5EF6,0x8FDF,0x8303,0x56F4,0xFF1A,0x0030,0x002D,0x0033,0x79D2,0xFF0C,0x63A8,0x8350,0x0031,0x79D2,0x3002))
$infoText.TextWrapping = 'Wrap'
$infoText.FontSize = 11
$infoText.Foreground = '#FF7DAA5A'
$infoText.Margin = '0,4,0,4'
$infoText.Opacity = 1
$infoText.FontWeight = 'Medium'
[void]$contentStack.Children.Add($infoText)

# Security info
$secText = New-Object System.Windows.Controls.TextBlock
$script:secText = $secText
$secText.Text = (CS @(0x1F512,0x0020,0x5B89,0x5168,0x63D0,0x793A,0xFF1A,0x5BC6,0x7801,0x4E0E,0x5B66,0x53F7,0x5747,0x52A0,0x5BC6,0x4FDD,0x5B58,0x5728,0x672C,0x5730,0x7535,0x8111,0x4E0A,0xFF0C,0x4EC5,0x60A8,0x7684,0x7535,0x8111,0x53EF,0x8BBF,0x95EE,0x3002))
$secText.TextWrapping = 'Wrap'
$secText.FontSize = 10.5
$secText.Foreground = '#FF8B9DC3'
$secText.Margin = '0,0,0,12'
$secText.Opacity = 1
$secText.FontStyle = 'Italic'
$secText.FontWeight = 'Medium'
[void]$contentStack.Children.Add($secText)

# Helper function to create rounded button style
function Set-ButtonStyle {
    param($Button, [int]$Radius = 10)
    $template = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <Border Background="{TemplateBinding Background}" 
            BorderBrush="{TemplateBinding BorderBrush}" 
            BorderThickness="{TemplateBinding BorderThickness}" 
            CornerRadius="$Radius">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
</ControlTemplate>
"@
    $Button.Template = [System.Windows.Markup.XamlReader]::Parse($template)
}

# Action buttons
$btnPanel = New-Object System.Windows.Controls.StackPanel
$btnPanel.Orientation = 'Horizontal'
$btnPanel.HorizontalAlignment = 'Center'
$btnPanel.Margin = '0,8,0,6'

$BtnRemoveTask = New-Object System.Windows.Controls.Button
$script:BtnRemoveTask = $BtnRemoveTask
$BtnRemoveTask.Content = (CS @(0x5220,0x9664,0x4EFB,0x52A1))
$BtnRemoveTask.Width = 100
$BtnRemoveTask.Height = 42
$BtnRemoveTask.Margin = '6,0'
$BtnRemoveTask.FontSize = 12
$BtnRemoveTask.Background = '#FFFFF0F0'
$BtnRemoveTask.Foreground = '#FFE57373'
$BtnRemoveTask.BorderThickness = 0
$BtnRemoveTask.Cursor = 'Hand'
# Add subtle border
$BtnRemoveTask.BorderBrush = '#FFFFCDD2'
$BtnRemoveTask.BorderThickness = '1.5'
Set-ButtonStyle -Button $BtnRemoveTask -Radius 10
[void]$btnPanel.Children.Add($BtnRemoveTask)

$BtnSave = New-Object System.Windows.Controls.Button
$script:BtnSave = $BtnSave
$BtnSave.Content = (CS @(0x4FDD,0x5B58,0x914D,0x7F6E))
$BtnSave.Width = 96
$BtnSave.Height = 42
$BtnSave.Margin = '6,0'
$BtnSave.FontSize = 12
$BtnSave.FontWeight = 'Medium'
$BtnSave.Background = '#FFFEF5E7'
$BtnSave.Foreground = '#FFF39C12'
$BtnSave.BorderBrush = '#FFFFE4B3'
$BtnSave.BorderThickness = '1.5'
$BtnSave.Cursor = 'Hand'
Set-ButtonStyle -Button $BtnSave -Radius 10
[void]$btnPanel.Children.Add($BtnSave)

$BtnSaveRun = New-Object System.Windows.Controls.Button
$script:BtnSaveRun = $BtnSaveRun
$BtnSaveRun.Content = (CS @(0x4FDD,0x5B58,0x5E76,0x8FDE,0x63A5))
$BtnSaveRun.Width = 120
$BtnSaveRun.Height = 42
$BtnSaveRun.Margin = '6,0'
$BtnSaveRun.FontSize = 12
$BtnSaveRun.FontWeight = 'Bold'
# Create gradient background
$saveRunBrush = New-Object System.Windows.Media.LinearGradientBrush
$saveRunBrush.StartPoint = '0,0'
$saveRunBrush.EndPoint = '1,1'
$saveRunStop1 = New-Object System.Windows.Media.GradientStop
$saveRunStop1.Color = '#FF42A5F5'
$saveRunStop1.Offset = 0
$saveRunStop2 = New-Object System.Windows.Media.GradientStop
$saveRunStop2.Color = '#FF26C6DA'
$saveRunStop2.Offset = 1
$saveRunBrush.GradientStops.Add($saveRunStop1)
$saveRunBrush.GradientStops.Add($saveRunStop2)
$BtnSaveRun.Background = $saveRunBrush
$BtnSaveRun.Foreground = '#FFFFFFFF'
$BtnSaveRun.BorderThickness = 0
$BtnSaveRun.Cursor = 'Hand'
# Add shadow effect
$BtnSaveRun.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
$BtnSaveRun.Effect.BlurRadius = 8
$BtnSaveRun.Effect.ShadowDepth = 2
$BtnSaveRun.Effect.Opacity = 0.3
$BtnSaveRun.Effect.Color = '#FF42A5F5'
Set-ButtonStyle -Button $BtnSaveRun -Radius 10
[void]$btnPanel.Children.Add($BtnSaveRun)

$BtnExit = New-Object System.Windows.Controls.Button
$script:BtnExit = $BtnExit
$BtnExit.Content = (CS @(0x9000,0x51FA))
$BtnExit.Width = 80
$BtnExit.Height = 42
$BtnExit.Margin = '6,0'
$BtnExit.FontSize = 12
$BtnExit.Background = '#FFF5F5F5'
$BtnExit.Foreground = '#FF90A4AE'
$BtnExit.BorderBrush = '#FFE0E0E0'
$BtnExit.BorderThickness = '1.5'
$BtnExit.Cursor = 'Hand'
Set-ButtonStyle -Button $BtnExit -Radius 10
[void]$btnPanel.Children.Add($BtnExit)

[void]$contentStack.Children.Add($btnPanel)

$scrollViewer.Content = $contentStack

$mainBorder.Child = $grid
$window.Content = $mainBorder

# Enable window dragging from entire window (except interactive controls)
$mainBorder.Add_MouseLeftButtonDown({ 
    param($s, $e)
    try { 
        # Allow dragging from anywhere on the border
        $window.DragMove() 
    } catch {}
})

# 初始化应用当前主题
try { Apply-Theme -ThemeIndex $script:currentTheme } catch {}

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
            wifi_names = @('JCU','SXL*','TSG*','YiShiTang*','ErShiTang*','JCI','JCItest')
            portal_entry_url = 'http://172.29.0.2/a79.htm'
            portal_probe_url = 'http://www.gstatic.com/generate_204'
            isp = ''
            ssid_rules = @()
            test_url = 'http://www.baidu.com'
            browser = 'edge'
            headless = $false
            autostart_delay_sec = 1
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
    $script:__wifiNamesAuto = @('JCU','SXL*','TSG*','YiShiTang*','ErShiTang*','JCI','JCItest')
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
            # 兼容旧配置：向下取整到整数，8-12秒的值转换为1秒
            $delayVal = [Math]::Round($delayVal, 0)
            if ($delayVal -gt 3) { $delayVal = 1 }
            if ($delayVal -lt 0) { $delayVal = 0 }
            $SldDelay.Value = [Math]::Max(0, [Math]::Min(3, $delayVal))
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
        $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
        if (-not (Test-Path $cfgPath)) { 
            $errMsg = ($script:texts[$lang].ConfigNotFoundError -f $cfgPath)
            Show-Error $errMsg $script:texts[$lang].ErrorTitle
            return
        }
        
        $obj = $null
        try {
            $obj = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            $errMsg = ($script:texts[$lang].ConfigFormatError -f $_.Exception.Message)
            Show-Error $errMsg $script:texts[$lang].ErrorTitle
            return
        }
        
        if (-not $obj) { 
            Show-Error $script:texts[$lang].ConfigInvalidError $script:texts[$lang].ErrorTitle
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
                $j['wifi_names'] = @('JCU','SXL*','TSG*','YiShiTang*','ErShiTang*','JCI','JCItest')
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
        
        # 获取用户设置的延迟时间（整数秒，Windows 任务计划不支持小数秒）
        $userDelay = [Math]::Round([double]$SldDelay.Value, 0)
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
            $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
            $errMsg = ($script:texts[$lang].ConfigSaveError -f $_.Exception.Message)
            Show-Error $errMsg $script:texts[$lang].ErrorTitle
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
        # 使用与配置文件一致的延迟值（支持小数）
        $loginDelay = $userDelay
        
        # 创建两个动作：先确保WLAN启动，再执行认证
        $authPath = Join-Path $stableRoot 'scripts\start_auth.ps1'
        
        # 主认证动作
        $argString = ('-WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $authPath)
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argString
        
        # 使用登录启动触发器（不受Windows快速启动影响）
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        # Windows 任务计划的 Delay 只支持整数秒
        # 用户设置的延迟时间（0-3秒）已经是整数，直接使用
        $loginDelayInt = [Math]::Max(0, [Math]::Round($loginDelay))
        $delayStr = "PT{0}S" -f $loginDelayInt
        $trigger.Delay = $delayStr
        # 显式启用触发器
        $trigger.Enabled = $true

        try {
            # 登录启动模式：使用Principal方式（无需密码）
            $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
            $taskResult = Register-ScheduledTask -TaskName 'CampusPortalAutoConnect' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop
            
            # 验证任务是否真的被创建
            Start-Sleep -Milliseconds 500
            $verifyTask = Get-ScheduledTask -TaskName 'CampusPortalAutoConnect' -ErrorAction SilentlyContinue
            if (-not $verifyTask) {
                throw "任务创建后验证失败：任务不存在"
            }
        } catch { 
            $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
            if ($_.Exception.Message -match "Access is denied|拒绝访问|0x80070005") {
                Show-Error $script:texts[$lang].PermissionErrorMessage $script:texts[$lang].PermissionErrorTitle
            } else {
                $errMsg = if ($lang -eq 'CN') { "创建任务失败：" + $_.Exception.Message } else { "Task creation failed: " + $_.Exception.Message }
                Show-Error $errMsg $script:texts[$lang].ErrorTitle
            }
            return
        }

        $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
        if ($andRun) {
            if (Test-Path $startScript) {
                $psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $startScript)
                Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -WindowStyle Hidden | Out-Null
                # 保存并连接：显示专业的成功提示
                $successMsg = ($script:texts[$lang].SaveAndConnectMessage -f $loginDelayInt)
                try { Show-Info $successMsg $script:texts[$lang].SaveAndConnectTitle } catch {}
            } else {
                $errMsg = if ($lang -eq 'CN') { "未找到认证脚本文件 start_auth.ps1" } else { "Authentication script file start_auth.ps1 not found" }
                Show-Error $errMsg $script:texts[$lang].ErrorTitle
            }
        } else {
            # 仅保存：显示专业的保存成功提示
            $successMsg = ($script:texts[$lang].SaveSuccessMessage -f $loginDelayInt)
            Show-Info $successMsg $script:texts[$lang].SaveSuccessTitle
        }
    } catch {
        $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
        $msg3 = if ($lang -eq 'CN') { "保存配置失败：" + $_.Exception.Message } else { "Configuration save failed: " + $_.Exception.Message }
        Show-Error $msg3 $script:texts[$lang].ErrorTitle
    }
}

# Remove Task Button Handler
$BtnRemoveTask.Add_Click({
    try {
        # Check if task exists (using schtasks to avoid XML parsing errors)
        $taskExists = $false
        try {
            $schtasksOutput = schtasks /Query /TN "CampusPortalAutoConnect" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $taskExists = $true
            }
        } catch {
            # Try PowerShell method as fallback
            $task = Get-ScheduledTask -TaskName 'CampusPortalAutoConnect' -ErrorAction SilentlyContinue
            if ($task) {
                $taskExists = $true
            }
        }
        
        if (-not $taskExists) {
            $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
            Show-Info $script:texts[$lang].TaskNotFoundMessage $script:texts[$lang].TaskNotFoundTitle
            return
        }
        
        # Confirm dialog - single confirmation for both task and data removal
        $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
        $confirmMsg = $script:texts[$lang].ConfirmRemoveMessage
        $result = Show-Question $confirmMsg $script:texts[$lang].ConfirmRemoveTitle
        
        if ($result) {
            $hasError = $false
            $errorDetails = ""
            
            # Remove scheduled task (force delete even if XML is corrupted)
            try {
                # Try PowerShell method first
                Unregister-ScheduledTask -TaskName 'CampusPortalAutoConnect' -Confirm:$false -ErrorAction Stop
            } catch {
                # If PowerShell method fails (e.g., due to corrupted XML), use schtasks
                try {
                    $deleteResult = schtasks /Delete /TN "CampusPortalAutoConnect" /F 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "schtasks 删除失败"
                    }
                } catch {
                    $hasError = $true
                    $errorDetails = "任务删除失败：$($_.Exception.Message)"
                }
            }
            
            # Clean application data (only important files, skip GUI images)
            if (-not $hasError) {
                $appDataPath = Join-Path $env:APPDATA 'CampusNet'
                $dataCleanSuccess = $false
                
                if (Test-Path $appDataPath) {
                    try {
                        # Clean up any running jobs first
                        Get-Job | Where-Object { $_.Name -match 'KeepAlive|UpdateCheck|Stats' } | Remove-Job -Force -ErrorAction SilentlyContinue
                        
                        # Delete important data files (configs, secrets, logs)
                        $importantFiles = @(
                            'config.json',
                            'config.default.json',
                            'secrets.json',
                            'campus_network.log',
                            'wifi_state.json'
                        )
                        
                        foreach ($file in $importantFiles) {
                            $filePath = Join-Path $appDataPath $file
                            if (Test-Path $filePath) {
                                try { Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue } catch {}
                            }
                        }
                        
                        # Delete script modules and other directories (but skip gui folder)
                        $foldersToDelete = @('scripts', 'portal_autofill', 'tasks')
                        foreach ($folder in $foldersToDelete) {
                            $folderPath = Join-Path $appDataPath $folder
                            if (Test-Path $folderPath) {
                                try { Remove-Item -Path $folderPath -Recurse -Force -ErrorAction SilentlyContinue } catch {}
                            }
                        }
                        
                        $dataCleanSuccess = $true
                        
                    } catch {
                        $dataCleanSuccess = $false
                    }
                } else {
                    $dataCleanSuccess = $true
                }
            }
            
            # Show result
            $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
            if (-not $hasError) {
                if ($dataCleanSuccess) {
                    $removeSuccessMsg = $script:texts[$lang].RemoveSuccessMessage
                    Show-Info $removeSuccessMsg $script:texts[$lang].RemoveSuccessTitle
                } else {
                    $removeSuccessMsg = $script:texts[$lang].RemovePartialMessage
                    Show-Info $removeSuccessMsg $script:texts[$lang].RemovePartialTitle
                }
            } else {
                Show-Error $errorDetails $script:texts[$lang].RemoveFailTitle
            }
        }
    } catch {
        $lang = if ($script:isEnglish) { 'EN' } else { 'CN' }
        $errMsg = if ($lang -eq 'CN') { "删除操作失败：" + $_.Exception.Message } else { "Removal operation failed: " + $_.Exception.Message }
        Show-Error $errMsg $script:texts[$lang].ErrorTitle
    }
})

$BtnSave.Add_Click({ Save-All $false })
$BtnSaveRun.Add_Click({ Save-All $true })
$BtnExit.Add_Click({ $window.Close() })

# Show quick guide on window loaded
$window.Add_Loaded({
    # Use Dispatcher to ensure window is fully rendered before showing guide
    $window.Dispatcher.Invoke([Action]{
        Show-QuickGuide
    }, [System.Windows.Threading.DispatcherPriority]::Background)
})

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
