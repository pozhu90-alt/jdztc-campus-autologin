# 小瓷连网 - 自动更新模块
# 功能：在线检查版本更新，支持后台下载和自动替换

$script:UpdateApiUrl = "https://1381467633-52ewvuipwd.ap-guangzhou.tencentscf.com"
$script:CurrentVersion = "1.0.0"

<#
.SYNOPSIS
    检查是否有新版本
    
.RETURNS
    如果有新版本，返回版本信息对象；否则返回 $null
#>
function Test-UpdateAvailable {
    try {
        # 请求版本信息
        $params = @{
            Uri = "$script:UpdateApiUrl/version"
            Method = 'GET'
            TimeoutSec = 5
            UseBasicParsing = $true
            ErrorAction = 'Stop'
        }
        
        $versionInfo = Invoke-RestMethod @params
        
        # 对比版本号
        $latestVer = [version]$versionInfo.latestVersion
        $currentVer = [version]$script:CurrentVersion
        
        if ($latestVer -gt $currentVer) {
            return $versionInfo
        }
        
        return $null
        
    } catch {
        # 检查失败，返回null
        return $null
    }
}

<#
.SYNOPSIS
    显示更新提示对话框
    
.PARAMETER VersionInfo
    从服务器获取的版本信息对象
    
.RETURNS
    用户选择：'Update', 'Later', 'Skip'
#>
function Show-UpdateDialog {
    param($VersionInfo)
    
    try {
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase
        
        # 创建对话框窗口
        $dialog = New-Object System.Windows.Window
        $dialog.Title = "发现新版本 - 小瓷连网"
        $dialog.Width = 520
        $dialog.Height = 380
        $dialog.WindowStartupLocation = 'CenterScreen'
        $dialog.ResizeMode = 'NoResize'
        $dialog.WindowStyle = 'None'
        $dialog.AllowsTransparency = $true
        $dialog.Background = 'Transparent'
        $dialog.Topmost = $true
        
        # 主边框（跟随主程序主题色，若可用）
        $mainBorder = New-Object System.Windows.Controls.Border
        $mainBorder.CornerRadius = 15
        try {
            if ($global:themes -and $global:currentTheme -ge 0) {
                $t = $global:themes[$global:currentTheme]
                $mainBorder.Background = $t.DialogBg
            } else {
                $mainBorder.Background = '#FFFFFFFF'
            }
        } catch { $mainBorder.Background = '#FFFFFFFF' }
        
        # 阴影
        $mainBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
        $mainBorder.Effect.BlurRadius = 20
        $mainBorder.Effect.ShadowDepth = 5
        $mainBorder.Effect.Opacity = 0.3
        
        $mainBorder.Padding = '30'
        
        # 内容面板
        $stackPanel = New-Object System.Windows.Controls.StackPanel
        $stackPanel.Margin = '10'
        
        # 标题
        $titleBlock = New-Object System.Windows.Controls.TextBlock
        $titleBlock.Text = "🎉 发现新版本！"
        $titleBlock.FontSize = 24
        $titleBlock.FontWeight = 'Bold'
        try {
            if ($global:themes -and $global:currentTheme -ge 0) { $titleBlock.Foreground = $global:themes[$global:currentTheme].DialogTitle } else { $titleBlock.Foreground = '#FF2C3E50' }
        } catch { $titleBlock.Foreground = '#FF2C3E50' }
        $titleBlock.TextAlignment = 'Center'
        $titleBlock.Margin = '0,0,0,20'
        [void]$stackPanel.Children.Add($titleBlock)
        
        # 版本信息
        $versionText = New-Object System.Windows.Controls.TextBlock
        $versionText.Text = "最新版本：v$($VersionInfo.latestVersion)`n当前版本：v$script:CurrentVersion"
        $versionText.FontSize = 14
        try { $versionText.Foreground = ($global:themes[$global:currentTheme]).DialogText } catch { $versionText.Foreground = '#FF5D6D7E' }
        $versionText.TextAlignment = 'Center'
        $versionText.Margin = '0,0,0,20'
        [void]$stackPanel.Children.Add($versionText)
        
        # 更新日志
        $logLabel = New-Object System.Windows.Controls.TextBlock
        $logLabel.Text = "✨ 更新内容："
        $logLabel.FontSize = 14
        $logLabel.FontWeight = 'Bold'
        try { $logLabel.Foreground = ($global:themes[$global:currentTheme]).DialogTitle } catch { $logLabel.Foreground = '#FF34495E' }
        $logLabel.Margin = '0,0,0,10'
        [void]$stackPanel.Children.Add($logLabel)
        
        $logScroll = New-Object System.Windows.Controls.ScrollViewer
        $logScroll.MaxHeight = 100
        $logScroll.VerticalScrollBarVisibility = 'Auto'
        $logScroll.Margin = '0,0,0,20'
        
        $logText = New-Object System.Windows.Controls.TextBlock
        $logText.Text = $VersionInfo.updateLog
        $logText.FontSize = 12
        try { $logText.Foreground = ($global:themes[$global:currentTheme]).DialogText } catch { $logText.Foreground = '#FF5D6D7E' }
        $logText.TextWrapping = 'Wrap'
        $logText.Padding = '10'
        $logScroll.Content = $logText
        [void]$stackPanel.Children.Add($logScroll)
        
        # 文件大小
        $sizeText = New-Object System.Windows.Controls.TextBlock
        $sizeText.Text = "文件大小：$($VersionInfo.downloadSize)"
        $sizeText.FontSize = 12
        $sizeText.Foreground = '#FF95A5A6'
        $sizeText.TextAlignment = 'Center'
        $sizeText.Margin = '0,0,0,20'
        [void]$stackPanel.Children.Add($sizeText)
        
        # 按钮面板
        $buttonPanel = New-Object System.Windows.Controls.StackPanel
        $buttonPanel.Orientation = 'Horizontal'
        $buttonPanel.HorizontalAlignment = 'Center'
        
        # 立即更新按钮
        $updateBtn = New-Object System.Windows.Controls.Button
        $updateBtn.Content = "🚀 立即更新"
        $updateBtn.Width = 120
        $updateBtn.Height = 36
        $updateBtn.Margin = '10,0'
        $updateBtn.FontSize = 14
        $updateBtn.FontWeight = 'Bold'
        try {
            $updateBtn.Foreground = ($global:themes[$global:currentTheme]).DialogAccentFg
            $updateBtn.Background = ($global:themes[$global:currentTheme]).DialogAccent
        } catch {
            $updateBtn.Foreground = 'White'
            $updateBtn.Background = '#FF3498DB'
        }
        $updateBtn.BorderThickness = 0
        $updateBtn.Cursor = 'Hand'
        $updateBtn.Tag = 'Update'
        $updateBtn.Add_Click({
            $dialog.Tag = 'Update'
            $dialog.Close()
        })
        [void]$buttonPanel.Children.Add($updateBtn)
        
        # 稍后提醒按钮
        $laterBtn = New-Object System.Windows.Controls.Button
        $laterBtn.Content = "⏰ 稍后提醒"
        $laterBtn.Width = 120
        $laterBtn.Height = 36
        $laterBtn.Margin = '10,0'
        $laterBtn.FontSize = 14
        try {
            $laterBtn.Foreground = ($global:themes[$global:currentTheme]).DialogCancelFg
            $laterBtn.Background = ($global:themes[$global:currentTheme]).DialogCancelBg
        } catch {
            $laterBtn.Foreground = '#FF5D6D7E'
            $laterBtn.Background = '#FFECF0F1'
        }
        $laterBtn.BorderThickness = 0
        $laterBtn.Cursor = 'Hand'
        $laterBtn.Tag = 'Later'
        $laterBtn.Add_Click({
            $dialog.Tag = 'Later'
            $dialog.Close()
        })
        [void]$buttonPanel.Children.Add($laterBtn)
        
        [void]$stackPanel.Children.Add($buttonPanel)
        
        $mainBorder.Child = $stackPanel
        $dialog.Content = $mainBorder
        
        # 默认结果
        $dialog.Tag = 'Later'
        
        # 显示对话框
        [void]$dialog.ShowDialog()
        
        return $dialog.Tag
        
    } catch {
        # UI显示失败，返回Later
        return 'Later'
    }
}

<#
.SYNOPSIS
    下载并安装更新
    
.PARAMETER DownloadUrl
    更新文件的下载URL
#>
function Install-Update {
    param([string]$DownloadUrl)
    
    try {
        Add-Type -AssemblyName PresentationFramework
        
        # 创建进度对话框
        $progressDialog = New-Object System.Windows.Window
        $progressDialog.Title = "下载更新中..."
        $progressDialog.Width = 400
        $progressDialog.Height = 180
        $progressDialog.WindowStartupLocation = 'CenterScreen'
        $progressDialog.ResizeMode = 'NoResize'
        $progressDialog.WindowStyle = 'None'
        $progressDialog.AllowsTransparency = $true
        $progressDialog.Background = 'Transparent'
        $progressDialog.Topmost = $true
        
        $progBorder = New-Object System.Windows.Controls.Border
        $progBorder.CornerRadius = 12
        $progBorder.Background = '#FFFFFFFF'
        $progBorder.Padding = '30'
        $progBorder.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
        $progBorder.Effect.BlurRadius = 15
        $progBorder.Effect.ShadowDepth = 3
        $progBorder.Effect.Opacity = 0.3
        
        $progStack = New-Object System.Windows.Controls.StackPanel
        
        $progTitle = New-Object System.Windows.Controls.TextBlock
        $progTitle.Text = "正在下载更新..."
        $progTitle.FontSize = 16
        $progTitle.FontWeight = 'Bold'
        $progTitle.Foreground = '#FF2C3E50'
        $progTitle.TextAlignment = 'Center'
        $progTitle.Margin = '0,0,0,20'
        [void]$progStack.Children.Add($progTitle)
        
        $progBar = New-Object System.Windows.Controls.ProgressBar
        $progBar.Height = 24
        $progBar.IsIndeterminate = $true
        $progBar.Foreground = '#FF3498DB'
        [void]$progStack.Children.Add($progBar)
        
        $progText = New-Object System.Windows.Controls.TextBlock
        $progText.Text = "请稍候..."
        $progText.FontSize = 12
        $progText.Foreground = '#FF95A5A6'
        $progText.TextAlignment = 'Center'
        $progText.Margin = '0,10,0,0'
        [void]$progStack.Children.Add($progText)
        
        $progBorder.Child = $progStack
        $progressDialog.Content = $progBorder
        
        # 异步下载
        $downloadJob = Start-Job -ScriptBlock {
            param($Url)
            $tempPath = Join-Path $env:TEMP "xiaoci_update_$(Get-Date -Format 'yyyyMMddHHmmss').exe"
            try {
                Invoke-WebRequest -Uri $Url -OutFile $tempPath -TimeoutSec 300 -UseBasicParsing
                return $tempPath
            } catch {
                return $null
            }
        } -ArgumentList $DownloadUrl
        
        # 显示进度窗口
        $progressDialog.Add_Loaded({
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromSeconds(1)
            $timer.Add_Tick({
                if ($downloadJob.State -eq 'Completed') {
                    $timer.Stop()
                    $progressDialog.Close()
                }
            })
            $timer.Start()
        })
        
        [void]$progressDialog.ShowDialog()
        
        # 获取下载结果
        $downloadedFile = Receive-Job -Job $downloadJob -Wait
        Remove-Job -Job $downloadJob
        
        if ($downloadedFile -and (Test-Path $downloadedFile)) {
            # 创建更新脚本
            $currentExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
            $updateScript = Join-Path $env:TEMP "xiaoci_update_script.ps1"
            
            $scriptContent = @"
# 更新脚本
Start-Sleep -Seconds 2

# 等待主程序退出
`$processName = [System.IO.Path]::GetFileNameWithoutExtension("$currentExe")
Get-Process | Where-Object { `$_.Name -eq `$processName } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# 替换文件
try {
    Copy-Item "$downloadedFile" "$currentExe" -Force
    Remove-Item "$downloadedFile" -Force -ErrorAction SilentlyContinue
    
    # 启动新版本
    Start-Process "$currentExe"
    
    # 显示成功消息
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "更新完成！小瓷连网已升级到最新版本。",
        "更新成功",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
} catch {
    # 显示失败消息
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "更新失败：`$(`$_.Exception.Message)`n`n请手动下载更新。",
        "更新失败",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
}

# 删除自己
Remove-Item "$updateScript" -Force -ErrorAction SilentlyContinue
"@
            
            Set-Content -Path $updateScript -Value $scriptContent -Encoding UTF8
            
            # 启动更新脚本并退出主程序
            Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$updateScript`"" -WindowStyle Hidden
            
            # 退出当前程序
            [System.Windows.Application]::Current.Shutdown()
            
            return $true
        } else {
            # 下载失败
            [System.Windows.MessageBox]::Show(
                "下载失败，请检查网络连接后重试。",
                "下载失败",
                'OK',
                'Error'
            )
            return $false
        }
        
    } catch {
        [System.Windows.MessageBox]::Show(
            "更新失败：$($_.Exception.Message)",
            "错误",
            'OK',
            'Error'
        )
        return $false
    }
}

<#
.SYNOPSIS
    检查并处理更新（主入口函数）
#>
function Invoke-UpdateCheck {
    try {
        # 检查是否有新版本
        $versionInfo = Test-UpdateAvailable
        
        if ($versionInfo) {
            # 显示更新对话框
            $userChoice = Show-UpdateDialog -VersionInfo $versionInfo
            
            if ($userChoice -eq 'Update') {
                # 用户选择更新
                Install-Update -DownloadUrl $versionInfo.downloadUrl
            }
        }
    } catch {
        # 更新检查失败，静默忽略
    }
}

<#
.SYNOPSIS
    设置当前版本号
#>
function Set-UpdaterVersion {
    param([string]$Version)
    $script:CurrentVersion = $Version
}

# 导出函数
Export-ModuleMember -Function @(
    'Test-UpdateAvailable',
    'Show-UpdateDialog',
    'Install-Update',
    'Invoke-UpdateCheck',
    'Set-UpdaterVersion'
)

