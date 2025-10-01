# 最简单的测试脚本
Add-Type -AssemblyName PresentationFramework

[System.Windows.MessageBox]::Show("程序已启动！`n如果看到这个消息，说明exe可以运行", '测试', 'OK', 'Information')

$stable = Join-Path $env:APPDATA 'CampusNet'
[System.Windows.MessageBox]::Show("稳定目录: $stable`n存在: $(Test-Path $stable)", '测试', 'OK', 'Information')

$gui = Join-Path $stable 'gui\config_gui.ps1'
[System.Windows.MessageBox]::Show("GUI路径: $gui`n存在: $(Test-Path $gui)", '测试', 'OK', 'Information')

if (Test-Path $gui) {
    [System.Windows.MessageBox]::Show("找到GUI脚本！即将运行...", '测试', 'OK', 'Information')
    $env:CAMPUSNET_SKIP_ADMIN_CHECK = '1'
    Set-Location (Split-Path $gui)
    & $gui
} else {
    [System.Windows.MessageBox]::Show("未找到GUI脚本！", '错误', 'OK', 'Error')
}

