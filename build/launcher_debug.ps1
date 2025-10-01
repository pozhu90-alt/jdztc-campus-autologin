$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

# 创建日志文件
$logFile = Join-Path $env:TEMP 'xiaoci_debug.log'
function Write-Log {
    param([string]$msg)
    try {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg" | Out-File -FilePath $logFile -Append -Encoding UTF8
    } catch {}
}

try {
    Write-Log "=== 程序启动 ==="
    Write-Log "日志文件: $logFile"
    
    # Skip console encoding in noConsole mode
    try {
        if ([Console]::InputEncoding) {
            [Console]::OutputEncoding = [Text.Encoding]::UTF8
            Write-Log "设置编码完成"
        }
    } catch {
        Write-Log "跳过控制台编码设置(noConsole模式)"
    }
    
    $stable = Join-Path $env:APPDATA 'CampusNet'
    Write-Log "稳定目录: $stable"
    
    $gui = Join-Path $stable 'gui\config_gui.ps1'
    $auth = Join-Path $stable 'scripts\start_auth.ps1'
    Write-Log "GUI路径: $gui"
    Write-Log "Auth路径: $auth"
    
    # Initialize user config on first run
    $cfg = Join-Path $stable 'config.json'
    $cfgDefault = Join-Path $stable 'config.default.json'
    Write-Log "配置文件: $cfg"
    Write-Log "默认配置: $cfgDefault"
    
    if (-not (Test-Path $cfg) -and (Test-Path $cfgDefault)) {
        Write-Log "复制默认配置..."
        try { 
            Copy-Item -LiteralPath $cfgDefault -Destination $cfg -Force -ErrorAction SilentlyContinue 
            Write-Log "配置文件复制成功"
        } catch {
            Write-Log "配置文件复制失败: $($_.Exception.Message)"
        }
    }
    
    if (Test-Path $gui) {
        Write-Log "找到GUI脚本"
        Write-Log "GUI文件大小: $((Get-Item $gui).Length) bytes"
        
        # Set environment variable
        $env:CAMPUSNET_SKIP_ADMIN_CHECK = '1'
        Write-Log "设置环境变量: CAMPUSNET_SKIP_ADMIN_CHECK=1"
        
        # Change to GUI directory
        $guiDir = Split-Path $gui
        Write-Log "切换目录到: $guiDir"
        Set-Location $guiDir
        Write-Log "当前目录: $(Get-Location)"
        
        # List files in GUI directory
        $files = Get-ChildItem $guiDir | Select-Object -ExpandProperty Name
        Write-Log "GUI目录文件列表: $($files -join ', ')"
        
        Write-Log "准备执行GUI脚本（绕过执行策略）..."
        
        # Execute GUI with bypassed execution policy
        try {
            $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden', '-File', $gui)
            Write-Log "PowerShell参数: $($psArgs -join ' ')"
            $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -NoNewWindow -PassThru -Wait
            Write-Log "GUI脚本执行完成，退出码: $($process.ExitCode)"
        } catch {
            Write-Log "GUI脚本执行出错: $($_.Exception.Message)"
            Write-Log "堆栈: $($_.ScriptStackTrace)"
        }
        
        Write-Log "准备退出..."
        [System.Environment]::Exit(0)
    }
    
    if (Test-Path $auth) {
        Write-Log "找到Auth脚本"
        Set-Location (Split-Path $auth)
        & $auth | Out-Null
        [System.Environment]::Exit(0)
    }
    
    Write-Log "未找到GUI或Auth脚本！"
    Write-Log "稳定目录内容:"
    if (Test-Path $stable) {
        Get-ChildItem $stable -Recurse | ForEach-Object {
            Write-Log "  $($_.FullName)"
        }
    } else {
        Write-Log "  稳定目录不存在！"
    }
    
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("未找到 GUI 或主脚本`n请查看日志: $logFile", '错误', 'OK', 'Error') | Out-Null
    exit 1
    
} catch {
    Write-Log "发生异常: $($_.Exception.Message)"
    Write-Log "异常类型: $($_.Exception.GetType().FullName)"
    Write-Log "堆栈: $($_.ScriptStackTrace)"
    
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show("程序出错，请查看日志:`n$logFile`n`n错误: $($_.Exception.Message)", '错误', 'OK', 'Error') | Out-Null
    } catch {}
    
    exit 1
}

