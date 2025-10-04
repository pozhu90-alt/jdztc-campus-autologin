# 小瓷连网 - 学校选择首页
param()

$ErrorActionPreference = 'SilentlyContinue'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# 加载学校配置
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptRoot
$schoolsConfigPath = Join-Path $rootPath "schools_config.json"

if (-not (Test-Path $schoolsConfigPath)) {
    [System.Windows.MessageBox]::Show("找不到学校配置文件！", "错误", "OK", "Error")
    exit 1
}

$schoolsConfig = Get-Content $schoolsConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

# 创建窗口
$window = New-Object System.Windows.Window
$window.Title = "小瓷连网 - 选择你的学校"
$window.Width = 600
$window.Height = 500
$window.WindowStartupLocation = 'CenterScreen'
$window.ResizeMode = 'NoResize'
$window.WindowStyle = 'None'
$window.AllowsTransparency = $true
$window.Background = 'Transparent'

# 主容器
$border = New-Object System.Windows.Controls.Border
$border.CornerRadius = 20
$border.Background = New-Object System.Windows.Media.LinearGradientBrush
$border.Background.StartPoint = '0,0'
$border.Background.EndPoint = '1,1'
$stop1 = New-Object System.Windows.Media.GradientStop
$stop1.Color = '#FFFFF9F0'
$stop1.Offset = 0
$stop2 = New-Object System.Windows.Media.GradientStop
$stop2.Color = '#FFFFF0E6'
$stop2.Offset = 1
$border.Background.GradientStops.Add($stop1)
$border.Background.GradientStops.Add($stop2)
$border.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
$border.Effect.BlurRadius = 30
$border.Effect.ShadowDepth = 0
$border.Effect.Opacity = 0.3
$border.Effect.Color = '#FF000000'

# 主布局
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = 20

# 行定义
$row1 = New-Object System.Windows.Controls.RowDefinition
$row1.Height = 'Auto'
$row2 = New-Object System.Windows.Controls.RowDefinition
$row2.Height = 'Auto'
$row3 = New-Object System.Windows.Controls.RowDefinition
$row3.Height = '*'
$row4 = New-Object System.Windows.Controls.RowDefinition
$row4.Height = 'Auto'
$grid.RowDefinitions.Add($row1)
$grid.RowDefinitions.Add($row2)
$grid.RowDefinitions.Add($row3)
$grid.RowDefinitions.Add($row4)

# 标题
$title = New-Object System.Windows.Controls.TextBlock
$title.Text = "🎓 小瓷连网"
$title.FontSize = 32
$title.FontWeight = 'Bold'
$title.HorizontalAlignment = 'Center'
$title.Margin = '0,20,0,10'
$title.Foreground = '#FF2C3E50'
[System.Windows.Controls.Grid]::SetRow($title, 0)
$grid.Children.Add($title)

# 副标题
$subtitle = New-Object System.Windows.Controls.TextBlock
$subtitle.Text = "请选择你的学校"
$subtitle.FontSize = 14
$subtitle.HorizontalAlignment = 'Center'
$subtitle.Margin = '0,0,0,20'
$subtitle.Foreground = '#FF7F8C8D'
[System.Windows.Controls.Grid]::SetRow($subtitle, 1)
$grid.Children.Add($subtitle)

# 搜索框容器
$searchPanel = New-Object System.Windows.Controls.StackPanel
$searchPanel.Margin = '40,0,40,10'
[System.Windows.Controls.Grid]::SetRow($searchPanel, 2)

# 搜索框
$searchBox = New-Object System.Windows.Controls.TextBox
$searchBox.Height = 40
$searchBox.FontSize = 14
$searchBox.Padding = '10,8'
$searchBox.BorderBrush = '#FFBDC3C7'
$searchBox.BorderThickness = 2
$searchBox.Text = "🔍 搜索学校名称..."
$searchBox.Foreground = '#FF95A5A6'
$searchPanel.Children.Add($searchBox)

# 学校列表
$listBox = New-Object System.Windows.Controls.ListBox
$listBox.Margin = '0,10,0,0'
$listBox.BorderThickness = 0
$listBox.Background = 'Transparent'
$listBox.FontSize = 14
$searchPanel.Children.Add($listBox)

# 填充学校列表
foreach ($school in $schoolsConfig.schools) {
    $item = New-Object System.Windows.Controls.ListBoxItem
    $item.Content = "📍 $($school.name) - $($school.city)"
    $item.Tag = $school.id
    $item.Padding = '15,10'
    $item.Margin = '0,2'
    $listBox.Items.Add($item)
}

$grid.Children.Add($searchPanel)

# 按钮面板
$buttonPanel = New-Object System.Windows.Controls.StackPanel
$buttonPanel.Orientation = 'Horizontal'
$buttonPanel.HorizontalAlignment = 'Center'
$buttonPanel.Margin = '0,20,0,20'
[System.Windows.Controls.Grid]::SetRow($buttonPanel, 3)

# 确定按钮
$btnOK = New-Object System.Windows.Controls.Button
$btnOK.Content = "确定"
$btnOK.Width = 120
$btnOK.Height = 40
$btnOK.FontSize = 14
$btnOK.Margin = '5'
$btnOK.Background = '#FF42A5F5'
$btnOK.Foreground = 'White'
$btnOK.BorderThickness = 0
$btnOK.Cursor = 'Hand'
$buttonPanel.Children.Add($btnOK)

# 退出按钮
$btnExit = New-Object System.Windows.Controls.Button
$btnExit.Content = "退出"
$btnExit.Width = 120
$btnExit.Height = 40
$btnExit.FontSize = 14
$btnExit.Margin = '5'
$btnExit.Background = '#FFE0E0E0'
$btnOK.Foreground = '#FF666666'
$btnExit.BorderThickness = 0
$btnExit.Cursor = 'Hand'
$buttonPanel.Children.Add($btnExit)

$grid.Children.Add($buttonPanel)

$border.Child = $grid
$window.Content = $border

# 搜索功能
$searchBox.Add_GotFocus({
    if ($searchBox.Text -eq "🔍 搜索学校名称...") {
        $searchBox.Text = ""
        $searchBox.Foreground = '#FF2C3E50'
    }
})

$searchBox.Add_LostFocus({
    if ([string]::IsNullOrWhiteSpace($searchBox.Text)) {
        $searchBox.Text = "🔍 搜索学校名称..."
        $searchBox.Foreground = '#FF95A5A6'
    }
})

$searchBox.Add_TextChanged({
    $searchText = $searchBox.Text
    if ($searchText -eq "🔍 搜索学校名称...") {
        return
    }
    
    $listBox.Items.Clear()
    foreach ($school in $schoolsConfig.schools) {
        if ($school.name -like "*$searchText*" -or $school.city -like "*$searchText*") {
            $item = New-Object System.Windows.Controls.ListBoxItem
            $item.Content = "📍 $($school.name) - $($school.city)"
            $item.Tag = $school.id
            $item.Padding = '15,10'
            $item.Margin = '0,2'
            $listBox.Items.Add($item)
        }
    }
})

# 确定按钮事件
$btnOK.Add_Click({
    if ($listBox.SelectedItem) {
        $selectedSchoolId = $listBox.SelectedItem.Tag
        
        # 保存选择
        $selection = @{
            school_id = $selectedSchoolId
            selected_at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        } | ConvertTo-Json
        
        $stableDir = Join-Path $env:APPDATA 'CampusNet'
        if (-not (Test-Path $stableDir)) {
            New-Item -ItemType Directory -Path $stableDir -Force | Out-Null
        }
        
        $selection | Out-File -FilePath (Join-Path $stableDir 'selected_school.json') -Encoding UTF8
        
        $window.DialogResult = $true
        $window.Close()
    } else {
        [System.Windows.MessageBox]::Show("请先选择一个学校！", "提示", "OK", "Warning")
    }
})

# 退出按钮事件
$btnExit.Add_Click({
    $window.Close()
})

# 窗口拖动
$border.Add_MouseLeftButtonDown({
    $window.DragMove()
})

# 显示窗口
$result = $window.ShowDialog()

if ($result) {
    exit 0  # 选择成功
} else {
    exit 1  # 用户取消
}

