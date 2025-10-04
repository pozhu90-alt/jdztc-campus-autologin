# 小瓷连网 - 匿名统计模块
# 功能：收集匿名使用统计，帮助改进工具

$script:StatsApiUrl = "https://1381467633-52ewvuipwd.ap-guangzhou.tencentscf.com"
$script:CurrentVersion = "1.0.0"

function Send-AnonymousStats {
    param(
        [switch]$Force,
        [int]$MaxWaitSec = 20
    )
    
    try {
        $deviceId = Get-AnonymousDeviceId
        $osInfo = [System.Environment]::OSVersion.VersionString
        
        $statsData = @{
            id = $deviceId
            v = $script:CurrentVersion
            t = [long]([datetime]::UtcNow - [datetime]'1970-01-01').TotalSeconds
            os = $osInfo
        }
        $stats = $statsData | ConvertTo-Json -Compress
        
        $job = Start-Job -ScriptBlock {
            param($Url, $Data)
            
            Start-Sleep -Seconds 6
            
            $attempt = 0
            $maxAttempts = 3
            $success = $false
            
            while ($attempt -lt $maxAttempts -and -not $success) {
                $attempt++
                
                if ($attempt -gt 1) {
                    Start-Sleep -Seconds ($attempt)
                }
                
                try {
                    $timeout = 5
                    $params = @{
                        Uri = "$Url/stats"
                        Method = 'POST'
                        Body = $Data
                        ContentType = 'application/json; charset=utf-8'
                        TimeoutSec = $timeout
                        UseBasicParsing = $true
                    }
                    
                    $response = Invoke-RestMethod @params
                    
                    if ($response.success -eq $true) {
                        $success = $true
                        return $true
                    }
                } catch {
                    # Retry
                }
            }
            
            return $false
        } -ArgumentList $script:StatsApiUrl, $stats
        
        $result = Wait-Job -Job $job -Timeout $MaxWaitSec
        $null = Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        
        return $result -ne $null
        
    } catch {
        return $false
    }
}

function Get-AnonymousDeviceId {
    try {
        $uuid = (Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID
        
        if (-not $uuid) {
            $cpuId = (Get-WmiObject Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).ProcessorId
            $boardSerial = (Get-WmiObject Win32_BaseBoard -ErrorAction SilentlyContinue).SerialNumber
            $uuid = "$cpuId-$boardSerial"
        }
        
        if (-not $uuid) {
            $uuid = $env:COMPUTERNAME
        }
        
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($uuid))
        $hashString = [Convert]::ToBase64String($hashBytes)
        
        return $hashString.Substring(0, 16)
        
    } catch {
        return [Guid]::NewGuid().ToString().Substring(0, 16)
    }
}

function Get-CurrentVersion {
    return $script:CurrentVersion
}

function Set-CurrentVersion {
    param([string]$Version)
    $script:CurrentVersion = $Version
}

Export-ModuleMember -Function @(
    'Send-AnonymousStats',
    'Get-AnonymousDeviceId',
    'Get-CurrentVersion',
    'Set-CurrentVersion'
)
