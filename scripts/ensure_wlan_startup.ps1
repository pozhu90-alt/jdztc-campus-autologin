# WLAN服务和适配器启动脚本
# 确保开机时WLAN服务正确启动并启用WiFi适配器

param()

$ErrorActionPreference = 'SilentlyContinue'

# 等待系统完全启动
Start-Sleep -Seconds 5

# 确保WLAN服务自动启动并运行
try {
    Set-Service -Name WlanSvc -StartupType Automatic
    Start-Service -Name WlanSvc
    
    # 等待服务完全启动
    $timeout = 15
    $elapsed = 0
    while ((Get-Service -Name WlanSvc).Status -ne 'Running' -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 1
        $elapsed++
    }
    
    Write-Host "WLAN服务状态: $((Get-Service -Name WlanSvc).Status)"
} catch {
    Write-Host "启动WLAN服务失败: $($_.Exception.Message)"
}

# 启用所有WiFi适配器
try {
    $wifiAdapters = Get-NetAdapter | Where-Object { $_.Name -match 'Wi-?Fi|Wireless|802\.11' }
    foreach ($adapter in $wifiAdapters) {
        if ($adapter.Status -ne 'Up') {
            Enable-NetAdapter -Name $adapter.Name -Confirm:$false
            Write-Host "启用WiFi适配器: $($adapter.Name)"
        }
    }
} catch {
    Write-Host "启用WiFi适配器失败: $($_.Exception.Message)"
}

# 确保网络发现服务也在运行
try {
    Start-Service -Name FDResPub -ErrorAction SilentlyContinue
    Start-Service -Name SSDPSRV -ErrorAction SilentlyContinue
} catch {}

Write-Host "WLAN启动检查完成"
