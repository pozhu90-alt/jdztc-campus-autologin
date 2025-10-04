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

# ============ About Dialog Function ============
function Show-AboutDialog {
    $aboutWin = New-Object System.Windows.Window
    $aboutWin.WindowStyle = 'None'
    $aboutWin.AllowsTransparency = $true
    $aboutWin.Background = 'Transparent'
    $aboutWin.Width = 550
    $aboutWin.Height = 600
    $aboutWin.WindowStartupLocation = 'CenterScreen'
    $aboutWin.ResizeMode = 'NoResize'
    $aboutWin.Topmost = $true
    
    # 主边框
    $aboutBorder = New-Object System.Windows.Controls.Border
    $aboutBorder.CornerRadius = 15
    $aboutBorder.Padding = '30'
    $aboutBorder.Background = New-Object System.Windows.Media.LinearGradientBrush
    $aboutBorder.Background.StartPoint = '0,0'
    $aboutBorder.Background.EndPoint = '0,1'
    $aboutBg1 = New-Object System.Windows.Media.GradientStop; $aboutBg1.Color = '#FFFFEFD5'; $aboutBg1.Offset = 0
    $aboutBg2 = New-Object System.Windows.Media.GradientStop; $aboutBg2.Color = '#FFFFFFFF'; $aboutBg2.Offset = 0.5
    $aboutBg3 = New-Object System.Windows.Media.GradientStop; $aboutBg3.Color = '#FFF5F5FF'; $aboutBg3.Offset = 1
    $aboutBorder.Background.GradientStops.Add($aboutBg1)
    $aboutBorder.Background.GradientStops.Add($aboutBg2)
    $aboutBorder.Background.GradientStops.Add($aboutBg3)
    $aboutBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $aboutBorder.Effect.BlurRadius = 25
    $aboutBorder.Effect.ShadowDepth = 5
    $aboutBorder.Effect.Opacity = 0.3
    
    $aboutStack = New-Object System.Windows.Controls.StackPanel
    
    # 标题
    $aboutTitle = New-Object System.Windows.Controls.TextBlock
    $aboutTitle.Text = "🌸 关于小瓷连网"
    $aboutTitle.FontSize = 24
    $aboutTitle.FontWeight = 'Bold'
    $aboutTitle.Foreground = '#FF6B4423'
    $aboutTitle.TextAlignment = 'Center'
    $aboutTitle.Margin = '0,0,0,20'
    [void]$aboutStack.Children.Add($aboutTitle)
    
    # 版本信息
    $versionText = New-Object System.Windows.Controls.TextBlock
    $versionText.Text = "版本 1.0.0"
    $versionText.FontSize = 14
    $versionText.Foreground = '#FF8B7355'
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
    $privacyTitle.Text = "📋 使用说明"
    $privacyTitle.FontSize = 16
    $privacyTitle.FontWeight = 'Bold'
    $privacyTitle.Foreground = '#FF2C3E50'
    $privacyTitle.Margin = '0,0,0,15'
    [void]$aboutStack.Children.Add($privacyTitle)
    
    # 隐私说明内容
    $privacyContent = @"
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
    
    $privacyScroll = New-Object System.Windows.Controls.ScrollViewer
    $privacyScroll.MaxHeight = 280
    $privacyScroll.VerticalScrollBarVisibility = 'Auto'
    $privacyScroll.Margin = '0,0,0,20'
    
    $privacyText = New-Object System.Windows.Controls.TextBlock
    $privacyText.Text = $privacyContent
    $privacyText.FontSize = 12
    $privacyText.Foreground = '#FF5D6D7E'
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
    $copyrightText.Text = "© 2025 小瓷连网 - 让连网更简单"
    $copyrightText.FontSize = 11
    $copyrightText.Foreground = '#FF95A5A6'
    $copyrightText.TextAlignment = 'Center'
    $copyrightText.Margin = '0,0,0,15'
    [void]$aboutStack.Children.Add($copyrightText)
    
    # 关闭按钮
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = "我知道了"
    $closeBtn.Width = 120
    $closeBtn.Height = 36
    $closeBtn.FontSize = 14
    $closeBtn.FontWeight = 'Bold'
    $closeBtn.Foreground = 'White'
    $closeBtn.Background = New-Object System.Windows.Media.LinearGradientBrush
    $closeBtn.Background.StartPoint = '0,0'
    $closeBtn.Background.EndPoint = '0,1'
    $closeBg1 = New-Object System.Windows.Media.GradientStop; $closeBg1.Color = '#FFFF9A76'; $closeBg1.Offset = 0
    $closeBg2 = New-Object System.Windows.Media.GradientStop; $closeBg2.Color = '#FFFF6B9D'; $closeBg2.Offset = 1
    $closeBtn.Background.GradientStops.Add($closeBg1)
    $closeBtn.Background.GradientStops.Add($closeBg2)
    $closeBtn.BorderThickness = 0
    $closeBtn.Cursor = 'Hand'
    $closeBtn.HorizontalAlignment = 'Center'
    $closeBtn.Add_Click({ $aboutWin.Close() })
    [void]$aboutStack.Children.Add($closeBtn)
    
    $aboutBorder.Child = $aboutStack
    $aboutWin.Content = $aboutBorder
    
    [void]$aboutWin.ShowDialog()
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
    
    # Main border with shadow - 高级渐变设计
    $border = New-Object System.Windows.Controls.Border
    $border.CornerRadius = 12
    $border.Padding = '0'
    
    # 根据类型创建明显且优雅的渐变背景
    $bgBrush = New-Object System.Windows.Media.LinearGradientBrush
    $bgBrush.StartPoint = '0,0'
    $bgBrush.EndPoint = '0,1'
    
    switch ($Type) {
        'Info' {
            # 清新蓝色渐变 - 从浅蓝到白色
            $bg1 = New-Object System.Windows.Media.GradientStop; $bg1.Color = '#FFD6E9FF'; $bg1.Offset = 0
            $bg2 = New-Object System.Windows.Media.GradientStop; $bg2.Color = '#FFE8F3FF'; $bg2.Offset = 0.35
            $bg3 = New-Object System.Windows.Media.GradientStop; $bg3.Color = '#FFF5FAFF'; $bg3.Offset = 0.65
            $bg4 = New-Object System.Windows.Media.GradientStop; $bg4.Color = '#FFFFFFFF'; $bg4.Offset = 1
        }
        'Error' {
            # 柔和红色渐变 - 从浅红到白色
            $bg1 = New-Object System.Windows.Media.GradientStop; $bg1.Color = '#FFFFD6D6'; $bg1.Offset = 0
            $bg2 = New-Object System.Windows.Media.GradientStop; $bg2.Color = '#FFFFE8E8'; $bg2.Offset = 0.35
            $bg3 = New-Object System.Windows.Media.GradientStop; $bg3.Color = '#FFFFF5F5'; $bg3.Offset = 0.65
            $bg4 = New-Object System.Windows.Media.GradientStop; $bg4.Color = '#FFFFFFFF'; $bg4.Offset = 1
        }
        'Warning' {
            # 温暖橙黄渐变 - 从浅橙到白色
            $bg1 = New-Object System.Windows.Media.GradientStop; $bg1.Color = '#FFFFE8CC'; $bg1.Offset = 0
            $bg2 = New-Object System.Windows.Media.GradientStop; $bg2.Color = '#FFFFF0DD'; $bg2.Offset = 0.35
            $bg3 = New-Object System.Windows.Media.GradientStop; $bg3.Color = '#FFFFF8EE'; $bg3.Offset = 0.65
            $bg4 = New-Object System.Windows.Media.GradientStop; $bg4.Color = '#FFFFFFFF'; $bg4.Offset = 1
        }
        'Question' {
            # 优雅紫色渐变 - 从浅紫到白色
            $bg1 = New-Object System.Windows.Media.GradientStop; $bg1.Color = '#FFE8DCFF'; $bg1.Offset = 0
            $bg2 = New-Object System.Windows.Media.GradientStop; $bg2.Color = '#FFF0E8FF'; $bg2.Offset = 0.35
            $bg3 = New-Object System.Windows.Media.GradientStop; $bg3.Color = '#FFF8F3FF'; $bg3.Offset = 0.65
            $bg4 = New-Object System.Windows.Media.GradientStop; $bg4.Color = '#FFFFFFFF'; $bg4.Offset = 1
        }
    }
    $bgBrush.GradientStops.Add($bg1)
    $bgBrush.GradientStops.Add($bg2)
    $bgBrush.GradientStops.Add($bg3)
    $bgBrush.GradientStops.Add($bg4)
    $border.Background = $bgBrush
    
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
            'Info' { $iconText.Text = '✓'; $iconText.Foreground = '#FF4A90E2' }
            'Error' { $iconText.Text = '✕'; $iconText.Foreground = '#FFE74C3C' }
            'Warning' { $iconText.Text = '⚠'; $iconText.Foreground = '#FFF39C12' }
            'Question' { $iconText.Text = '?'; $iconText.Foreground = '#FF9B59B6' }
        }
        [void]$titlePanel.Children.Add($iconText)
        
        # 标题文字 - 简洁专业
        $titleText = New-Object System.Windows.Controls.TextBlock
        $titleText.Text = $Title
        $titleText.FontSize = 17
        $titleText.FontWeight = 'SemiBold'
        $titleText.Foreground = '#FF2C3E50'
        $titleText.VerticalAlignment = 'Center'
        [void]$titlePanel.Children.Add($titleText)
        
        [void]$contentStack.Children.Add($titlePanel)
    }
    
    # Message - 高级排版
    $msgText = New-Object System.Windows.Controls.TextBlock
    $msgText.Text = $Message
    $msgText.TextWrapping = 'Wrap'
    $msgText.FontSize = 13.5
    $msgText.Foreground = '#FF596066'
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
        $btnNo.Background = '#FFF8F9FA'
        $btnNo.Foreground = '#FF7F8C8D'
        $btnNo.BorderBrush = '#FFDFE4E8'
        $btnNo.BorderThickness = '1'
        $btnNo.Cursor = 'Hand'
        $btnNo.FontFamily = 'Microsoft YaHei UI'
        $btnNo.Template = [System.Windows.Markup.XamlReader]::Parse($buttonTemplate)
        $btnNo.Add_MouseEnter({ $this.Background = '#FFF0F2F5' })
        $btnNo.Add_MouseLeave({ $this.Background = '#FFF8F9FA' })
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
    
    # 根据类型设置按钮颜色 - 纯色更高级
    switch ($Type) {
        'Info' { 
            $btnYes.Background = '#FF4A90E2'
            $btnYes.Add_MouseEnter({ $this.Background = '#FF3A80D2' })
            $btnYes.Add_MouseLeave({ $this.Background = '#FF4A90E2' })
        }
        'Error' { 
            $btnYes.Background = '#FFE74C3C'
            $btnYes.Add_MouseEnter({ $this.Background = '#FFD73C2C' })
            $btnYes.Add_MouseLeave({ $this.Background = '#FFE74C3C' })
        }
        'Warning' { 
            $btnYes.Background = '#FFF39C12'
            $btnYes.Add_MouseEnter({ $this.Background = '#FFE38C02' })
            $btnYes.Add_MouseLeave({ $this.Background = '#FFF39C12' })
        }
        'Question' { 
            $btnYes.Background = '#FF9B59B6'
            $btnYes.Add_MouseEnter({ $this.Background = '#FF8B49A6' })
            $btnYes.Add_MouseLeave({ $this.Background = '#FF9B59B6' })
        }
    }
    
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

# Define two columns: left decorative panel + right content panel
$cd0 = New-Object System.Windows.Controls.ColumnDefinition; $cd0.Width='360'; [void]$grid.ColumnDefinitions.Add($cd0)
$cd1 = New-Object System.Windows.Controls.ColumnDefinition; $cd1.Width='*';   [void]$grid.ColumnDefinitions.Add($cd1)

# ============ LEFT PANEL: Decorative Ceramic-style Panel ============
$leftPanel = New-Object System.Windows.Controls.Border
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
$leftStack.Margin = '40,60,40,60'

# Decorative circle (ceramic avatar placeholder) - Can be replaced with image
$avatarBorder = New-Object System.Windows.Controls.Border
$avatarBorder.Width = 180
$avatarBorder.Height = 180
$avatarBorder.CornerRadius = 90
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
        Center = New-Object System.Windows.Point(90, 90)
        RadiusX = 90
        RadiusY = 90
    }
    [void]$avatarGrid.Children.Add($avatarImage)
} else {
    # Inner decorative element (default gradient)
    $innerCircle = New-Object System.Windows.Controls.Ellipse
    $innerCircle.Width = 120
    $innerCircle.Height = 120
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
$titleBlock.Text = (CS @(0x5C0F,0x74F7))
$titleBlock.FontSize = 28
$titleBlock.FontWeight = 'Bold'
$titleBlock.Foreground = '#FF2C3E50'
$titleBlock.TextAlignment = 'Center'
$titleBlock.Margin = '0,0,0,12'
[void]$leftStack.Children.Add($titleBlock)

# Subtitle
$subtitleBlock = New-Object System.Windows.Controls.TextBlock
$subtitleBlock.Text = (CS @(0x5C0F,0x74F7,0x4E3A,0x4E3B,0x4EBA,0x8FDE,0x63A5,0x7F51,0x7EDC,0x8036,0xFF01))
$subtitleBlock.FontSize = 12
$subtitleBlock.Foreground = '#FF6B4423'
$subtitleBlock.TextAlignment = 'Center'
$subtitleBlock.Margin = '0,0,0,30'
$subtitleBlock.Opacity = 0.85
[void]$leftStack.Children.Add($subtitleBlock)

# Decorative dots
$dotsPanel = New-Object System.Windows.Controls.StackPanel
$dotsPanel.Orientation = 'Horizontal'
$dotsPanel.HorizontalAlignment = 'Center'
$dotsPanel.Margin = '0,20,0,0'
foreach ($color in @('#FFFF6B9D', '#FF4ECDC4', '#FF95E1D3')) {
    $dot = New-Object System.Windows.Controls.Ellipse
    $dot.Width = 12
    $dot.Height = 12
    $dot.Fill = $color
    $dot.Margin = '6,0'
    $dot.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $dot.Effect.BlurRadius = 8
    $dot.Effect.ShadowDepth = 0
    $dot.Effect.Opacity = 0.4
    [void]$dotsPanel.Children.Add($dot)
}
[void]$leftStack.Children.Add($dotsPanel)

$leftPanel.Child = $leftStack

# ============ GRADIENT TRANSITION LAYER ============
$gradientLayer = New-Object System.Windows.Controls.Border
$gradientLayer.Width = 320
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

# ============ RIGHT PANEL: Content Area ============
$rightPanel = New-Object System.Windows.Controls.Grid
[System.Windows.Controls.Grid]::SetColumn($rightPanel,1)
[void]$grid.Children.Add($rightPanel)

# ============ ABOUT BUTTON (Top Left) ============
$aboutButton = New-Object System.Windows.Controls.Button
$aboutButton.Width = 80
$aboutButton.Height = 32
$aboutButton.HorizontalAlignment = 'Left'
$aboutButton.VerticalAlignment = 'Top'
$aboutButton.Margin = '20,18,0,0'
$aboutButton.Content = "ℹ 关于"
$aboutButton.FontSize = 13
$aboutButton.FontWeight = 'SemiBold'
$aboutButton.Foreground = '#FF6B4423'
$aboutButton.Background = New-Object System.Windows.Media.LinearGradientBrush
$aboutButton.Background.StartPoint = '0,0'
$aboutButton.Background.EndPoint = '0,1'
$abg1 = New-Object System.Windows.Media.GradientStop; $abg1.Color = '#FFFFEFD5'; $abg1.Offset = 0
$abg2 = New-Object System.Windows.Media.GradientStop; $abg2.Color = '#FFFFD9A8'; $abg2.Offset = 1
$aboutButton.Background.GradientStops.Add($abg1)
$aboutButton.Background.GradientStops.Add($abg2)
$aboutButton.BorderThickness = 0
$aboutButton.Cursor = 'Hand'
$aboutButton.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
$aboutButton.Effect.BlurRadius = 8
$aboutButton.Effect.ShadowDepth = 2
$aboutButton.Effect.Opacity = 0.25
$aboutButton.Effect.Color = '#FF000000'

# 圆角按钮模板
$aboutButton.Template = New-Object System.Windows.Controls.ControlTemplate(System.Windows.Controls.Button)
$aboutButtonFactory = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.Border])
$aboutButtonFactory.SetValue([System.Windows.Controls.Border]::CornerRadiusProperty, (New-Object System.Windows.CornerRadius(16)))
$aboutButtonFactory.SetValue([System.Windows.Controls.Border]::BackgroundProperty, (New-Object System.Windows.TemplateBindingExtension([System.Windows.Controls.Border]::BackgroundProperty)))
$aboutButtonFactory.SetValue([System.Windows.Controls.Border]::BorderBrushProperty, (New-Object System.Windows.TemplateBindingExtension([System.Windows.Controls.Border]::BorderBrushProperty)))
$aboutButtonFactory.SetValue([System.Windows.Controls.Border]::BorderThicknessProperty, (New-Object System.Windows.TemplateBindingExtension([System.Windows.Controls.Border]::BorderThicknessProperty)))

$aboutContentFactory = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.ContentPresenter])
$aboutContentFactory.SetValue([System.Windows.Controls.ContentPresenter]::HorizontalAlignmentProperty, [System.Windows.HorizontalAlignment]::Center)
$aboutContentFactory.SetValue([System.Windows.Controls.ContentPresenter]::VerticalAlignmentProperty, [System.Windows.VerticalAlignment]::Center)
$aboutButtonFactory.AppendChild($aboutContentFactory)

$aboutButton.Template.VisualTree = $aboutButtonFactory

# 鼠标悬停效果
$aboutButton.Add_MouseEnter({
    $this.Opacity = 0.85
})
$aboutButton.Add_MouseLeave({
    $this.Opacity = 1.0
})

# 点击事件 - 显示关于对话框
$aboutButton.Add_Click({
    Show-AboutDialog
})

[System.Windows.Controls.Panel]::SetZIndex($aboutButton, 101)
[void]$rightPanel.Children.Add($aboutButton)

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

[void]$rightPanel.Children.Add($windowButtonsPanel)

# Content scroll viewer
$scrollViewer = New-Object System.Windows.Controls.ScrollViewer
$scrollViewer.VerticalScrollBarVisibility = 'Hidden'
$scrollViewer.Margin = '40,65,40,20'
[void]$rightPanel.Children.Add($scrollViewer)

# Content stack panel
$contentStack = New-Object System.Windows.Controls.StackPanel
$contentStack.Margin = '0'

# Helper function to create styled input container
function New-InputGroup {
    param([string]$Label, $Control, [string]$Icon = '')
    
    $container = New-Object System.Windows.Controls.StackPanel
    $container.Margin = '0,0,0,10'
    
    $labelBlock = New-Object System.Windows.Controls.TextBlock
    $labelText = if ($Icon) { "$Icon  $Label" } else { $Label }
    $labelBlock.Text = $labelText
    $labelBlock.FontSize = 12
    $labelBlock.Foreground = '#FF8B6F47'
    $labelBlock.Margin = '0,0,0,6'
    $labelBlock.FontWeight = 'SemiBold'
    [void]$container.Children.Add($labelBlock)
    
    $controlBorder = New-Object System.Windows.Controls.Border
    # 使用柔和的渐变背景 - 更细腻的过渡
    $controlBorder.Background = New-Object System.Windows.Media.LinearGradientBrush
    $controlBorder.Background.StartPoint = '0,0'
    $controlBorder.Background.EndPoint = '0,1'
    $cbStop1 = New-Object System.Windows.Media.GradientStop
    $cbStop1.Color = '#FFFFFFFE'
    $cbStop1.Offset = 0
    $cbStop2 = New-Object System.Windows.Media.GradientStop
    $cbStop2.Color = '#FFFFFEFB'
    $cbStop2.Offset = 0.5
    $cbStop3 = New-Object System.Windows.Media.GradientStop
    $cbStop3.Color = '#FFFFFDF8'
    $cbStop3.Offset = 1
    $controlBorder.Background.GradientStops.Add($cbStop1)
    $controlBorder.Background.GradientStops.Add($cbStop2)
    $controlBorder.Background.GradientStops.Add($cbStop3)
    
    $controlBorder.BorderBrush = '#FFEDD4B0'
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
    
    return $container
}

# Username
$TxtUser = New-Object System.Windows.Controls.TextBox
$TxtUser.FontSize = 13.5
$TxtUser.BorderThickness = 0
$TxtUser.Background = 'Transparent'
$TxtUser.Foreground = '#FF5D4E37'
$TxtUser.FontWeight = 'Medium'
$TxtUser.CaretBrush = '#FFCCA060'
[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x5B66,0x5DE5,0x53F7,0xFF1A))) -Control $TxtUser))

# Password
$PwdBox = New-Object System.Windows.Controls.PasswordBox
$PwdBox.FontSize = 13.5
$PwdBox.BorderThickness = 0
$PwdBox.Background = 'Transparent'
$PwdBox.Foreground = '#FF5D4E37'
$PwdBox.FontWeight = 'Medium'
[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x6570,0x5B57,0x5316,0x0028,0x4E91,0x9676,0x0029,0x5BC6,0x7801,0xFF1A))) -Control $PwdBox))

# Delay slider
$delayContainer = New-Object System.Windows.Controls.StackPanel
$delayInner = New-Object System.Windows.Controls.StackPanel
$delayInner.Orientation = 'Horizontal'
$SldDelay = New-Object System.Windows.Controls.Slider
$SldDelay.Minimum = 0
$SldDelay.Maximum = 3
$SldDelay.Value = 1
$SldDelay.Width = 180
$SldDelay.TickFrequency = 0.1
$SldDelay.IsSnapToTickEnabled = $false
$SldDelay.Foreground = '#FFCCA060'
$SldDelay.VerticalAlignment = 'Center'
$LblDelay = New-Object System.Windows.Controls.TextBlock
$LblDelay.Text = '1.0' + (CS @(0x79D2))
$LblDelay.Margin = '16,0,0,0'
$LblDelay.FontSize = 14
$LblDelay.FontWeight = 'Bold'
$LblDelay.Foreground = '#FFD4A574'
$LblDelay.VerticalAlignment = 'Center'
$SldDelay.add_ValueChanged({ try { $LblDelay.Text = ([Math]::Round($SldDelay.Value, 1)).ToString('0.0') + (CS @(0x79D2)) } catch {} })
[void]$delayInner.Children.Add($SldDelay)
[void]$delayInner.Children.Add($LblDelay)
$delayContainer.Children.Add((New-InputGroup -Label ((CS @(0x767B,0x5F55,0x5EF6,0x8FDF,0xFF1A))) -Control $delayInner))
[void]$contentStack.Children.Add($delayContainer)

# ISP Combo
$CmbISP = New-Object System.Windows.Controls.ComboBox
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
[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x8FD0,0x8425,0x5546,0xFF1A))) -Control $CmbISP))

# Wi-Fi selection
$wifiPanel = New-Object System.Windows.Controls.StackPanel
$wifiPanel.Orientation = 'Horizontal'
$RbAuto = New-Object System.Windows.Controls.RadioButton
$RbAuto.Content = (CS @(0x5B66,0x6821,0x7F51))
$RbAuto.IsChecked = $true
$RbAuto.Margin = '0,0,30,0'
$RbAuto.FontSize = 13
$RbAuto.Foreground = '#FF5D4E37'
$RbAuto.FontWeight = 'Medium'
$RbJCI = New-Object System.Windows.Controls.RadioButton
$RbJCI.Content = (CS @(0x6821,0x56ED,0x7F51,0x004A,0x0043,0x0049))
$RbJCI.FontSize = 13
$RbJCI.Foreground = '#FF5D4E37'
$RbJCI.FontWeight = 'Medium'
[void]$wifiPanel.Children.Add($RbAuto)
[void]$wifiPanel.Children.Add($RbJCI)

# Add WiFi hint text
$wifiHintText = New-Object System.Windows.Controls.TextBlock
$wifiHintText.Text = (CS @(0x5B66,0x6821,0x7F51,0x5305,0x542B,0x6821,0x56ED,0x7F51,0xFF1B,0x5355,0x8FDE,0x6821,0x56ED,0x7F51,0x901F,0x5EA6,0x66F4,0x5FEB))
$wifiHintText.FontSize = 10.5
$wifiHintText.Foreground = '#FF8B9DC3'
$wifiHintText.Margin = '0,8,0,0'
$wifiHintText.FontStyle = 'Italic'
$wifiHintText.Opacity = 0.85
[void]$wifiPanel.Children.Add($wifiHintText)

[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x0057,0x0069,0x002D,0x0046,0x0069,0x0020,0x9009,0x62E9,0xFF1A))) -Control $wifiPanel))

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
[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x0057,0x0069,0x002D,0x0046,0x0069,0x4FE1,0x53F7,0x4F4E,0x4E8E,0x767E,0x5206,0x503C,0x4E0D,0x8FDE,0x63A5,0xFF1A))) -Control $signalInner))

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
[void]$contentStack.Children.Add((New-InputGroup -Label ((CS @(0x6D4F,0x89C8,0x5668,0xFF1A))) -Control $CmbBrowser))

# Info text
$infoText = New-Object System.Windows.Controls.TextBlock
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
            Show-Error ("配置文件未找到：" + $cfgPath) '错误'
            return
        }
        
        $obj = $null
        try {
            $obj = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Show-Error ("配置文件格式错误：" + $_.Exception.Message) '错误'
            return
        }
        
        if (-not $obj) { 
            Show-Error "配置文件内容无效，请检查配置文件。" '错误'
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
            Show-Error ("保存配置文件失败：" + $_.Exception.Message) '错误'
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
        # Windows 任务计划的 Delay 只支持整数秒，需要向上取整
        # 用户设置的延迟时间（0.1-3秒）会被转换为整数秒
        $loginDelayInt = [Math]::Max(1, [Math]::Ceiling($loginDelay))
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
            if ($_.Exception.Message -match "Access is denied|拒绝访问|0x80070005") {
                Show-Error "权限不足：请以管理员身份运行本程序。" '权限错误'
            } else {
                Show-Error ("创建任务失败：" + $_.Exception.Message) '错误'
            }
            return
        }

        if ($andRun) {
            if (Test-Path $startScript) {
                $psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $startScript)
                Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -WindowStyle Hidden | Out-Null
                # 保存并连接：显示专业的成功提示
                $successMsg = "配置已保存并创建登录启动任务（延迟 {0} 秒）`n`n正在连接校园网络..." -f $loginDelayInt
                try { Show-Info $successMsg '操作成功' } catch {}
            } else {
                Show-Error "未找到认证脚本文件 start_auth.ps1" '错误'
            }
        } else {
            # 仅保存：显示专业的保存成功提示
            $successMsg = "登录启动任务已创建（延迟 {0} 秒）`n`n配置信息已成功保存。" -f $loginDelayInt
            Show-Info $successMsg '配置已保存'
        }
    } catch {
        $msg3 = "保存配置失败：" + $_.Exception.Message
        Show-Error $msg3 '错误'
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
            Show-Info "当前系统中未找到自动启动任务。" '提示'
            return
        }
        
        # Confirm dialog - single confirmation for both task and data removal
        $confirmMsg = "确认要删除自动启动任务吗？`n`n此操作将：`n• 删除登录自动连接任务`n• 清理程序配置和数据`n`n删除后需要重新配置程序。"
        $result = Show-Question $confirmMsg '确认删除'
        
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
            if (-not $hasError) {
                if ($dataCleanSuccess) {
                    $removeSuccessMsg = "程序已卸载。`n`n✅ 自动启动任务已删除`n✅ 配置和凭据已清理`n`n如需重新使用，请重新运行程序。"
                    Show-Info $removeSuccessMsg '卸载成功'
                } else {
                    $removeSuccessMsg = "任务已删除。`n`n✅ 自动启动任务已删除`n⚠️ 部分数据清理失败`n`n如需重新使用，请重新运行程序。"
                    Show-Info $removeSuccessMsg '部分成功'
                }
            } else {
                Show-Error $errorDetails '删除失败'
            }
        }
    } catch {
        $errMsg = "删除操作失败：" + $_.Exception.Message
        Show-Error $errMsg '错误'
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
