# 小瓷连网 - 匿名统计模块
# 功能：收集匿名使用统计，帮助改进工具

$script:StatsApiUrl = "https://1381467633-52ewvuipwd.ap-guangzhou.tencentscf.com"
$script:CurrentVersion = "1.0.0"

<#
.SYNOPSIS
    发送匿名统计数据到云端
    
.DESCRIPTION
    完全匿名，只收集：
    - 设备ID（硬件信息哈希，无法反推）
    - 程序版本号
    - 启动时间戳
    - 操作系统版本
    
.PARAMETER Force
    强制发送统计（默认会检查是否已发送）
#>
function Send-AnonymousStats {
    param(
        [switch]$Force
    )
    
    try {
        # 生成匿名设备ID
        $deviceId = Get-AnonymousDeviceId
        
        # 获取OS信息
        $osInfo = [System.Environment]::OSVersion.VersionString
        
        # 构造统计数据
        $stats = @{
            id = $deviceId
            v = $script:CurrentVersion
            t = [long]([datetime]::UtcNow - [datetime]'1970-01-01').TotalSeconds
            os = $osInfo
        } | ConvertTo-Json -Compress
        
        # 异步发送（不阻塞主程序）
        Start-Job -ScriptBlock {
            param($Url, $Data)
            try {
                $params = @{
                    Uri = "$Url/stats"
                    Method = 'POST'
                    Body = $Data
                    ContentType = 'application/json; charset=utf-8'
                    TimeoutSec = 3
                    UseBasicParsing = $true
                    ErrorAction = 'SilentlyContinue'
                }
                Invoke-RestMethod @params | Out-Null
            } catch {
                # 静默失败，不影响程序
            }
        } -ArgumentList $script:StatsApiUrl, $stats | Out-Null
        
    } catch {
        # 统计失败不影响程序运行
    }
}

<#
.SYNOPSIS
    生成匿名设备ID
    
.DESCRIPTION
    基于硬件信息生成哈希ID，特点：
    - 同一台电脑ID相同（用于去重）
    - 无法反推硬件信息
    - 保护用户隐私
#>
function Get-AnonymousDeviceId {
    try {
        # 获取主板UUID（相对稳定的硬件标识）
        $uuid = (Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID
        
        if (-not $uuid) {
            # 备用方案：使用CPU ID + 主板序列号
            $cpuId = (Get-WmiObject Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).ProcessorId
            $boardSerial = (Get-WmiObject Win32_BaseBoard -ErrorAction SilentlyContinue).SerialNumber
            $uuid = "$cpuId-$boardSerial"
        }
        
        if (-not $uuid) {
            # 最后备用方案：使用机器名
            $uuid = $env:COMPUTERNAME
        }
        
        # 生成 SHA256 哈希
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($uuid))
        $hashString = [Convert]::ToBase64String($hashBytes)
        
        # 返回前16位作为设备ID
        return $hashString.Substring(0, 16)
        
    } catch {
        # 如果所有方法都失败，返回一个随机ID
        return [Guid]::NewGuid().ToString().Substring(0, 16)
    }
}

<#
.SYNOPSIS
    获取当前程序版本号
#>
function Get-CurrentVersion {
    return $script:CurrentVersion
}

<#
.SYNOPSIS
    设置程序版本号
#>
function Set-CurrentVersion {
    param([string]$Version)
    $script:CurrentVersion = $Version
}

# 导出函数
Export-ModuleMember -Function @(
    'Send-AnonymousStats',
    'Get-AnonymousDeviceId',
    'Get-CurrentVersion',
    'Set-CurrentVersion'
)

