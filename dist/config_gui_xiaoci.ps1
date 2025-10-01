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

# Custom styled message box functions
function Show-CustomDialog {
    param(
        [string]$Message,
        [string]$Title = '',
        [string]$Type = 'Info',  # Info, Error, Warning, Question
        [bool]$ShowCancel = $false,
        [string]$DecorativeText = ''  # 装饰性文字，用于显示在右上角
    )
    
    $dialogWin = New-Object System.Windows.Window
    $dialogWin.WindowStyle = 'None'
    $dialogWin.AllowsTransparency = $true
    $dialogWin.Background = 'Transparent'
    $dialogWin.Width = 480
    $dialogWin.SizeToContent = 'Height'
    $dialogWin.WindowStartupLocation = 'CenterScreen'
    $dialogWin.ResizeMode = 'NoResize'
    $dialogWin.Topmost = $true
    
    # Main border with shadow
    $border = New-Object System.Windows.Controls.Border
    $border.CornerRadius = 16
    $border.Background = '#FFFFFFFF'
    $border.Padding = '0'
    $border.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $border.Effect.BlurRadius = 30
    $border.Effect.ShadowDepth = 0
    $border.Effect.Opacity = 0.25
    $border.Effect.Color = '#FF000000'
    
    $mainStack = New-Object System.Windows.Controls.StackPanel
    
    # Header with gradient based on type
    $header = New-Object System.Windows.Controls.Border
    $header.Height = 8
    $header.CornerRadius = '16,16,0,0'
    $headerBrush = New-Object System.Windows.Media.LinearGradientBrush
    $headerBrush.StartPoint = '0,0'
    $headerBrush.EndPoint = '1,0'
    
    switch ($Type) {
        'Info' {
            $hs1 = New-Object System.Windows.Media.GradientStop; $hs1.Color = '#FF42A5F5'; $hs1.Offset = 0
            $hs2 = New-Object System.Windows.Media.GradientStop; $hs2.Color = '#FF26C6DA'; $hs2.Offset = 1
        }
        'Error' {
            $hs1 = New-Object System.Windows.Media.GradientStop; $hs1.Color = '#FFEF5350'; $hs1.Offset = 0
            $hs2 = New-Object System.Windows.Media.GradientStop; $hs2.Color = '#FFFF7043'; $hs2.Offset = 1
        }
        'Warning' {
            $hs1 = New-Object System.Windows.Media.GradientStop; $hs1.Color = '#FFFFA726'; $hs1.Offset = 0
            $hs2 = New-Object System.Windows.Media.GradientStop; $hs2.Color = '#FFFFCA28'; $hs2.Offset = 1
        }
        'Question' {
            $hs1 = New-Object System.Windows.Media.GradientStop; $hs1.Color = '#FFFFBF66'; $hs1.Offset = 0
            $hs2 = New-Object System.Windows.Media.GradientStop; $hs2.Color = '#FFFFD180'; $hs2.Offset = 1
        }
    }
    $headerBrush.GradientStops.Add($hs1)
    $headerBrush.GradientStops.Add($hs2)
    $header.Background = $headerBrush
    [void]$mainStack.Children.Add($header)
    
    # Content area
    $contentStack = New-Object System.Windows.Controls.StackPanel
    $contentStack.Margin = '40,30,40,30'
    
    # Icon and Title row
    if ($Title) {
        $titlePanel = New-Object System.Windows.Controls.StackPanel
        $titlePanel.Orientation = 'Horizontal'
        $titlePanel.Margin = '0,0,0,20'
        
        # Icon
        $iconText = New-Object System.Windows.Controls.TextBlock
        $iconText.FontSize = 28
        $iconText.Margin = '0,0,12,0'
        $iconText.VerticalAlignment = 'Center'
        
        switch ($Type) {
            'Info' { $iconText.Text = '✓'; $iconText.Foreground = '#FF42A5F5' }
            'Error' { $iconText.Text = '✕'; $iconText.Foreground = '#FFEF5350' }
            'Warning' { $iconText.Text = '⚠'; $iconText.Foreground = '#FFFFA726' }
            'Question' { $iconText.Text = '?'; $iconText.Foreground = '#FFFFBF66' }
        }
        [void]$titlePanel.Children.Add($iconText)
        
        # Title text
        $titleText = New-Object System.Windows.Controls.TextBlock
        $titleText.Text = $Title
        $titleText.FontSize = 18
        $titleText.FontWeight = 'Bold'
        $titleText.Foreground = '#FF2C3E50'
        $titleText.VerticalAlignment = 'Center'
        [void]$titlePanel.Children.Add($titleText)
        
        [void]$contentStack.Children.Add($titlePanel)
    }
    
    # Message
    $msgText = New-Object System.Windows.Controls.TextBlock
    $msgText.Text = $Message
    $msgText.TextWrapping = 'Wrap'
    $msgText.FontSize = 13
    $msgText.Foreground = '#FF5F6368'
    $msgText.LineHeight = 22
    $msgText.Margin = '0,0,0,30'
    [void]$contentStack.Children.Add($msgText)
    
    # Buttons
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = 'Horizontal'
    $btnPanel.HorizontalAlignment = 'Right'
    
    # Rounded corners template (shared by all buttons)
    $buttonTemplate = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <Border Background="{TemplateBinding Background}" 
            BorderBrush="{TemplateBinding BorderBrush}" 
            BorderThickness="{TemplateBinding BorderThickness}" 
            CornerRadius="8">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
</ControlTemplate>
"@
    
    if ($ShowCancel) {
        # Cancel button
        $btnNo = New-Object System.Windows.Controls.Button
        $btnNo.Content = if ($Type -eq 'Question') { (CS @(0x5426,0x0028,0x004E,0x0029)) } else { (CS @(0x53D6,0x6D88)) }
        $btnNo.Width = 90
        $btnNo.Height = 36
        $btnNo.Margin = '0,0,10,0'
        $btnNo.FontSize = 12
        $btnNo.Background = '#FFF5F5F5'
        $btnNo.Foreground = '#FF90A4AE'
        $btnNo.BorderBrush = '#FFE0E0E0'
        $btnNo.BorderThickness = '1.5'
        $btnNo.Cursor = 'Hand'
        $btnNo.Template = [System.Windows.Markup.XamlReader]::Parse($buttonTemplate)
        $btnNo.Add_Click({
            $dialogWin.Tag = $false
            $dialogWin.Close()
        })
        [void]$btnPanel.Children.Add($btnNo)
    }
    
    # OK/Yes button
    $btnYes = New-Object System.Windows.Controls.Button
    $btnYes.Content = if ($ShowCancel -and $Type -eq 'Question') { (CS @(0x662F,0x0028,0x0059,0x0029)) } else { (CS @(0x786E,0x5B9A)) }
    $btnYes.Width = 90
    $btnYes.Height = 36
    $btnYes.FontSize = 12
    $btnYes.FontWeight = 'Bold'
    $btnYes.Foreground = '#FFFFFFFF'
    $btnYes.BorderThickness = 0
    $btnYes.Cursor = 'Hand'
    
    # Gradient background
    $yesBrush = New-Object System.Windows.Media.LinearGradientBrush
    $yesBrush.StartPoint = '0,0'
    $yesBrush.EndPoint = '1,0'
    
    switch ($Type) {
        'Info' {
            $ys1 = New-Object System.Windows.Media.GradientStop; $ys1.Color = '#FF42A5F5'; $ys1.Offset = 0
            $ys2 = New-Object System.Windows.Media.GradientStop; $ys2.Color = '#FF26C6DA'; $ys2.Offset = 1
        }
        'Error' {
            $ys1 = New-Object System.Windows.Media.GradientStop; $ys1.Color = '#FFEF5350'; $ys1.Offset = 0
            $ys2 = New-Object System.Windows.Media.GradientStop; $ys2.Color = '#FFFF7043'; $ys2.Offset = 1
        }
        'Warning' {
            $ys1 = New-Object System.Windows.Media.GradientStop; $ys1.Color = '#FFFFA726'; $ys1.Offset = 0
            $ys2 = New-Object System.Windows.Media.GradientStop; $ys2.Color = '#FFFFCA28'; $ys2.Offset = 1
        }
        'Question' {
            $ys1 = New-Object System.Windows.Media.GradientStop; $ys1.Color = '#FFFFBF66'; $ys1.Offset = 0
            $ys2 = New-Object System.Windows.Media.GradientStop; $ys2.Color = '#FFFFD180'; $ys2.Offset = 1
        }
    }
    $yesBrush.GradientStops.Add($ys1)
    $yesBrush.GradientStops.Add($ys2)
    $btnYes.Background = $yesBrush
    
    $btnYes.Template = [System.Windows.Markup.XamlReader]::Parse($buttonTemplate)
    $btnYes.Add_Click({
        $dialogWin.Tag = $true
        $dialogWin.Close()
    })
    [void]$btnPanel.Children.Add($btnYes)
    
    [void]$contentStack.Children.Add($btnPanel)
    [void]$mainStack.Children.Add($contentStack)
    
    $border.Child = $mainStack
    
    # Close button (X) at top right
    $closeBtn = New-Object System.Windows.Controls.Button
    $closeBtn.Content = '×'
    $closeBtn.Width = 32
    $closeBtn.Height = 32
    $closeBtn.FontSize = 20
    $closeBtn.FontWeight = 'Bold'
    $closeBtn.Background = 'Transparent'
    $closeBtn.Foreground = '#FF90A4AE'
    $closeBtn.BorderThickness = 0
    $closeBtn.Cursor = 'Hand'
    $closeBtn.HorizontalAlignment = 'Right'
    $closeBtn.VerticalAlignment = 'Top'
    $closeBtn.Margin = '0,10,10,0'
    
    $closeTemplate = @"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <Border Background="{TemplateBinding Background}" CornerRadius="16">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
</ControlTemplate>
"@
    $closeBtn.Template = [System.Windows.Markup.XamlReader]::Parse($closeTemplate)
    $closeBtn.Add_MouseEnter({ $closeBtn.Foreground = '#FFEF5350' })
    $closeBtn.Add_MouseLeave({ $closeBtn.Foreground = '#FF90A4AE' })
    $closeBtn.Add_Click({
        $dialogWin.Tag = $false
        $dialogWin.Close()
    })
    
    # Overlay close button on top of content using Grid
    $overlayGrid = New-Object System.Windows.Controls.Grid
    [void]$overlayGrid.Children.Add($border)
    [void]$overlayGrid.Children.Add($closeBtn)
    
    # Add decorative text if provided (rotated 45 degrees)
    if ($DecorativeText) {
        $decorativeTextBlock = New-Object System.Windows.Controls.TextBlock
        $decorativeTextBlock.Text = $DecorativeText
        $decorativeTextBlock.FontSize = 14
        $decorativeTextBlock.FontWeight = 'Bold'
        
        # Set color based on dialog type
        switch ($Type) {
            'Info' { $decorativeTextBlock.Foreground = '#FF42A5F5' }
            'Error' { $decorativeTextBlock.Foreground = '#FFEF5350' }
            'Warning' { $decorativeTextBlock.Foreground = '#FFFFA726' }
            'Question' { $decorativeTextBlock.Foreground = '#FFD4A574' }
        }
        
        $decorativeTextBlock.HorizontalAlignment = 'Right'
        $decorativeTextBlock.VerticalAlignment = 'Top'
        $decorativeTextBlock.Margin = '0,85,60,0'
        $decorativeTextBlock.Opacity = 0.88
        
        # Apply rotation transform (30 degrees clockwise)
        $rotateTransform = New-Object System.Windows.Media.RotateTransform
        $rotateTransform.Angle = 30
        $decorativeTextBlock.RenderTransform = $rotateTransform
        $decorativeTextBlock.RenderTransformOrigin = '0.5,0.5'
        
        # Set high ZIndex to ensure it's above everything except close button
        [System.Windows.Controls.Panel]::SetZIndex($decorativeTextBlock, 98)
        [System.Windows.Controls.Panel]::SetZIndex($closeBtn, 99)
        
        [void]$overlayGrid.Children.Add($decorativeTextBlock)
    }
    
    $dialogWin.Content = $overlayGrid
    
    $dialogWin.Tag = $false
    [void]$dialogWin.ShowDialog()
    return $dialogWin.Tag
}

function Show-Info([string]$msg, [string]$title = '', [string]$decorative = '') { 
    [void](Show-CustomDialog -Message $msg -Title $title -Type 'Info' -DecorativeText $decorative)
}

function Show-Error([string]$msg, [string]$title = '', [string]$decorative = '') { 
    [void](Show-CustomDialog -Message $msg -Title $title -Type 'Error' -DecorativeText $decorative)
}

function Show-Question([string]$msg, [string]$title = '', [string]$decorative = '') {
    return (Show-CustomDialog -Message $msg -Title $title -Type 'Question' -ShowCancel $true -DecorativeText $decorative)
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
$mainBorder.Background.StartPoint = '0,0'
$mainBorder.Background.EndPoint = '1,1'
$stop1 = New-Object System.Windows.Media.GradientStop; $stop1.Color = '#FFFFF9F0'; $stop1.Offset = 0
$stop2 = New-Object System.Windows.Media.GradientStop; $stop2.Color = '#FFFFF0E6'; $stop2.Offset = 1
$mainBorder.Background.GradientStops.Add($stop1)
$mainBorder.Background.GradientStops.Add($stop2)
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
$lgStop1 = New-Object System.Windows.Media.GradientStop; $lgStop1.Color = '#FFFFE8B8'; $lgStop1.Offset = 0
$lgStop2 = New-Object System.Windows.Media.GradientStop; $lgStop2.Color = '#FFFFD68F'; $lgStop2.Offset = 0.5
$lgStop3 = New-Object System.Windows.Media.GradientStop; $lgStop3.Color = '#FFFFC570'; $lgStop3.Offset = 1
$leftPanel.Background.GradientStops.Add($lgStop1)
$leftPanel.Background.GradientStops.Add($lgStop2)
$leftPanel.Background.GradientStops.Add($lgStop3)
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
$gradientLayer.Width = 220
$gradientLayer.HorizontalAlignment = 'Left'
$gradientLayer.Background = New-Object System.Windows.Media.LinearGradientBrush
$gradientLayer.Background.StartPoint = '0,0'
$gradientLayer.Background.EndPoint = '1,0'
$gStop1 = New-Object System.Windows.Media.GradientStop; $gStop1.Color = '#FFFFC570'; $gStop1.Offset = 0
$gStop2 = New-Object System.Windows.Media.GradientStop; $gStop2.Color = '#FFFFD99A'; $gStop2.Offset = 0.2
$gStop3 = New-Object System.Windows.Media.GradientStop; $gStop3.Color = '#FFFFE8C4'; $gStop3.Offset = 0.4
$gStop4 = New-Object System.Windows.Media.GradientStop; $gStop4.Color = '#FFFFF3DC'; $gStop4.Offset = 0.6
$gStop5 = New-Object System.Windows.Media.GradientStop; $gStop5.Color = '#FFFFF8ED'; $gStop5.Offset = 0.8
$gStop6 = New-Object System.Windows.Media.GradientStop; $gStop6.Color = '#FFFFF9F0'; $gStop6.Offset = 1
$gradientLayer.Background.GradientStops.Add($gStop1)
$gradientLayer.Background.GradientStops.Add($gStop2)
$gradientLayer.Background.GradientStops.Add($gStop3)
$gradientLayer.Background.GradientStops.Add($gStop4)
$gradientLayer.Background.GradientStops.Add($gStop5)
$gradientLayer.Background.GradientStops.Add($gStop6)
[System.Windows.Controls.Grid]::SetColumn($gradientLayer,1)
$gradientLayer.IsHitTestVisible = $false
[void]$grid.Children.Add($gradientLayer)

# ============ RIGHT PANEL: Content Area ============
$rightPanel = New-Object System.Windows.Controls.Grid
[System.Windows.Controls.Grid]::SetColumn($rightPanel,1)
[void]$grid.Children.Add($rightPanel)

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
    # 使用渐变背景
    $controlBorder.Background = New-Object System.Windows.Media.LinearGradientBrush
    $controlBorder.Background.StartPoint = '0,0'
    $controlBorder.Background.EndPoint = '0,1'
    $cbStop1 = New-Object System.Windows.Media.GradientStop
    $cbStop1.Color = '#FFFFFDF8'
    $cbStop1.Offset = 0
    $cbStop2 = New-Object System.Windows.Media.GradientStop
    $cbStop2.Color = '#FFFFFAF2'
    $cbStop2.Offset = 1
    $controlBorder.Background.GradientStops.Add($cbStop1)
    $controlBorder.Background.GradientStops.Add($cbStop2)
    
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
                # 保存并连接：显示保存成功和正在连接的提示
                $successMsg = (CS @(0x2705,0x0020,0x767B,0x5F55,0x542F,0x52A8,0x4EFB,0x52A1,0x5DF2,0x521B,0x5EFA,0x0020,0x0028,0x5EF6,0x8FDF,0x007B,0x0030,0x007D,0x79D2,0x0029,0x000A,0x000A,0x914D,0x7F6E,0x5DF2,0x4FDD,0x5B58,0xFF0C,0x6B63,0x5728,0x8FDE,0x63A5,0x6821,0x56ED,0x7F51,0x2026)) -f $loginDelay
                $decorativeMsg = (CS @(0x4E3B,0x4EBA,0xFF0C,0x5C0F,0x74F7,0x5F00,0x59CB,0x5DE5,0x4F5C,0x5566,0x007E))
                try { Show-Info $successMsg -decorative $decorativeMsg } catch {}
            } else {
                Show-Error "start_auth.ps1 not found."
            }
        } else {
            # 仅保存：显示任务创建成功和配置保存的提示
            $successMsg = (CS @(0x2705,0x0020,0x767B,0x5F55,0x542F,0x52A8,0x4EFB,0x52A1,0x5DF2,0x521B,0x5EFA,0x0020,0x0028,0x5EF6,0x8FDF,0x007B,0x0030,0x007D,0x79D2,0x0029,0x000A,0x000A,0x914D,0x7F6E,0x5DF2,0x4FDD,0x5B58,0xFF01)) -f $loginDelay
            $decorativeMsg = (CS @(0x4E3B,0x4EBA,0xFF0C,0x8BBE,0x7F6E,0x5DF2,0x8BB0,0x4F4F,0x5566,0xFF01))
            Show-Info $successMsg -decorative $decorativeMsg
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
            $noTaskMsg = (CS @(0x4EFB,0x52A1,0x8BA1,0x5212,0x4E0D,0x5B58,0x5728,0xFF0C,0x65E0,0x9700,0x5220,0x9664))
            $noTaskDecorativeMsg = (CS @(0x4E3B,0x4EBA,0xFF0C,0x5C0F,0x74F7,0x8FD8,0x6CA1,0x5F00,0x59CB,0x5462,0x007E))
            Show-Info $noTaskMsg -decorative $noTaskDecorativeMsg
            return
        }
        
        # Confirm dialog
        $result = Show-Question `
            -msg (CS @(0x786E,0x8BA4,0x8981,0x5220,0x9664,0x5F00,0x673A,0x81EA,0x52A8,0x8FDE,0x63A5,0x4EFB,0x52A1,0xFF1F,0x000A,0x000A,0x5220,0x9664,0x540E,0xFF0C,0x7A0B,0x5E8F,0x5C06,0x4E0D,0x4F1A,0x5728,0x767B,0x5F55,0x65F6,0x81EA,0x52A8,0x8FDE,0x63A5,0x6821,0x56ED,0x7F51,0x3002,0x000A,0x5982,0x679C,0x4E0D,0x518D,0x4F7F,0x7528,0x672C,0x7A0B,0x5E8F,0xFF0C,0x8BF7,0x5220,0x9664,0x4EFB,0x52A1,0x540E,0x518D,0x5220,0x9664,0x0020,0x0065,0x0078,0x0065,0x0020,0x6587,0x4EF6,0x3002)) `
            -title (CS @(0x786E,0x8BA4,0x5220,0x9664)) `
            -decorative (CS @(0x4E3B,0x4EBA,0x4E0D,0x8981,0x5C0F,0x74F7,0x4E86,0x5417,0xFF1F))
        
        if ($result) {
            # Remove scheduled task
            Unregister-ScheduledTask -TaskName 'CampusPortalAutoConnect' -Confirm:$false -ErrorAction Stop
            
            # Success message
            $removeSuccessMsg = (CS @(0x2705,0x0020,0x4EFB,0x52A1,0x8BA1,0x5212,0x5DF2,0x6210,0x529F,0x5220,0x9664,0xFF01,0x000A,0x000A,0x7A0B,0x5E8F,0x5C06,0x4E0D,0x4F1A,0x5728,0x767B,0x5F55,0x65F6,0x81EA,0x52A8,0x8FD0,0x884C,0x3002,0x000A,0x5982,0x679C,0x8981,0x5378,0x8F7D,0x7A0B,0x5E8F,0xFF0C,0x8BF7,0x624B,0x52A8,0x5220,0x9664,0x0020,0x0065,0x0078,0x0065,0x0020,0x6587,0x4EF6,0x3002))
            $removeDecorativeMsg = (CS @(0x5C0F,0x74F7,0x4F1A,0x60F3,0x4E3B,0x4EBA,0x7684,0x007E))
            Show-Info $removeSuccessMsg -decorative $removeDecorativeMsg
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
