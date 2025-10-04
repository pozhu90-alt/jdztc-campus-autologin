# 测试版launcher - 会显示详细错误信息
param()

# 启用详细错误
$ErrorActionPreference = 'Continue'
$VerbosePreference = 'Continue'

Add-Type -AssemblyName PresentationFramework

function Show-Error {
    param([string]$msg)
    [System.Windows.MessageBox]::Show($msg, '错误诊断', 'OK', 'Error')
}

try {
    $stable = Join-Path $env:APPDATA 'CampusNet'
    Show-Error "稳定目录: $stable"
    
    if (-not (Test-Path $stable)) {
        Show-Error "稳定目录不存在，正在创建..."
        New-Item -ItemType Directory -Path $stable -Force | Out-Null
    }
    
    $gui = Join-Path $stable 'gui\config_gui.ps1'
    Show-Error "GUI路径: $gui`n存在: $(Test-Path $gui)"
    
    if (Test-Path $gui) {
        $guiContent = Get-Content $gui -Raw
        Show-Error "GUI文件大小: $($guiContent.Length) 字符"
        
        # 检查.NET版本
        $dotnet = [System.Diagnostics.FileVersionInfo]::GetVersionInfo([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory() + "mscorlib.dll").ProductVersion
        Show-Error ".NET版本: $dotnet"
        
        Show-Error "准备执行GUI脚本..."
        $env:CAMPUSNET_SKIP_ADMIN_CHECK = '1'
        Set-Location (Split-Path $gui)
        & $gui
        Show-Error "GUI脚本执行完成"
    } else {
        Show-Error "未找到GUI脚本！"
    }
} catch {
    Show-Error "错误: $($_.Exception.Message)`n`n堆栈: $($_.ScriptStackTrace)"
}

Show-Error "程序即将退出"

