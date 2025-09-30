param()

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfgPath = Join-Path $root '..\config.json'
$logPath = Join-Path (Split-Path $root -Parent) 'campus_network.log'

function Log {
    param(
        [string]$msg,
        [string]$level = "INFO"
    )
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] [$level] $msg"
    try { 
        $line | Out-File -FilePath $logPath -Append -Encoding UTF8 
    } 
    catch { 
        # 忽略日志写入错误
    }
    Write-Host $msg
}

try {
    $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {
    Log -msg "Config read failed: $($_.Exception.Message)" -level "ERROR"
    exit 1
}

# 精准开机延迟：GUI中配置的小数秒通过 boot_extra_delay_ms 传递到这里
try {
    if ($cfg.boot_extra_delay_ms -and [int]$cfg.boot_extra_delay_ms -gt 0) {
        Start-Sleep -Milliseconds ([int]$cfg.boot_extra_delay_ms)
    }
} catch {}

try {
    Import-Module "$root\modules\wifi.psm1" -Force
    Log -msg "✅ WiFi module loaded"
} catch {
    Log -msg "❌ WiFi module failed: $($_.Exception.Message)" -level "ERROR"
}

try {
    Import-Module "$root\modules\netdetect.psm1" -Force 
    Log -msg "✅ NetDetect module loaded"
} catch {
    Log -msg "❌ NetDetect module failed: $($_.Exception.Message)" -level "ERROR"
}

try {
    Import-Module "$root\modules\security.psm1" -Force
    Log -msg "✅ Security module loaded"
} catch {
    Log -msg "❌ Security module failed: $($_.Exception.Message)" -level "ERROR"
}

try {
    Import-Module "$root\modules\cdp.psm1" -Force
    Log -msg "✅ CDP module loaded"
    
    # 验证CDP函数是否可用
    if (Get-Command Invoke-CDPAutofill -ErrorAction SilentlyContinue) {
        Log -msg "✅ Invoke-CDPAutofill function available"
    } else {
        Log -msg "❌ Invoke-CDPAutofill function NOT available" -level "ERROR"
    }
} catch {
    Log -msg "❌ CDP module failed: $($_.Exception.Message)" -level "ERROR"
}

# ===== 0) 启动前环境预检查：附近是否有校园网，信号是否足够 =====
try {
    $allScan = Scan-WifiNetworks
} catch { $allScan = @() }

# 允许运行时自定义最低信号门槛（百分比），未配置时默认 30%
$minSignal = 30
try {
    if ($null -ne $cfg.min_signal_percent -and '' -ne $cfg.min_signal_percent) {
        $minSignal = [int]$cfg.min_signal_percent
    }
} catch {}

$ssidList = @()
try { $ssidList = @($cfg.wifi_names) } catch { $ssidList = @() }

if (-not $allScan -or $allScan.Count -eq 0) {
    Log -msg "附近未发现任何 Wi‑Fi，当前可能不在校园网覆盖范围内，跳过认证。" -level "WARN"
    exit 0
}

$campusHits = @()
foreach ($n in $ssidList) {
    $hit = $allScan | Where-Object {
        if ($n -match '^\^') { $_.Ssid -match $n }                 # 正则
        elseif ($n -match '[\*\?]') { $_.Ssid -like $n }           # 通配符
        else { $_.Ssid -eq $n }                                    # 精确
    } | Sort-Object Signal -Descending | Select-Object -First 1
    if ($hit) { $campusHits += $hit }
}

if ($campusHits.Count -eq 0) {
    Log -msg ("附近未发现校园网 SSID（期望: " + ($ssidList -join ', ') + "），跳过认证。") -level "WARN"
    exit 0
}

$best = ($campusHits | Sort-Object Signal -Descending)[0]
Log -msg ("检测到校园网 '$($best.Ssid)'，信号强度=$($best.Signal)%（阈值=$minSignal%）")
if ([int]$best.Signal -lt [int]$minSignal) {
    Log -msg "校园网信号过弱，可能无法稳定认证，跳过本次流程。" -level "WARN"
    exit 0
}

Log "Start auth pipeline"

# 1) 智能WiFi检测
$connected = $false

# 首先检查是否已经有网络连接
$probeInfo = Get-ActiveWifiInfo
if ($probeInfo -and $probeInfo.IPv4 -and ($probeInfo.IPv4 -notmatch '^169\.')) {
    Log -msg "WiFi already connected: IP=$($probeInfo.IPv4)"
    $connected = $true
} else {
    # 尝试自动连接
    Log -msg "Attempting WiFi connection (smart scan) ..."
    $connectOk = $false
    # 启动阶段网卡可能尚未完全就绪：尝试多次快速连接
    try {
        $connectOk = $false
        for ($t=0; $t -lt 2 -and -not $connectOk; $t++) {
            $connectOk = Connect-WifiSmart -WifiNames $cfg.wifi_names -QuickWaitSec 2 -SignalMargin 10
            if (-not $connectOk) { Start-Sleep -Milliseconds 300 }
        }
    } catch { $connectOk = $false }
    Log -msg ("Connect-WifiSmart returned: $connectOk")
    if ($connectOk) {
        $connected = $true
        Log -msg "WiFi connected successfully"
    } else {
        # 自动连接失败，等待用户手动连接
        Log -msg "Auto WiFi connect failed, waiting for manual connect (up to 30s)" -level "WARN"
        $wait = 0
        do {
            $probeInfo = Get-ActiveWifiInfo
            if ($probeInfo -and $probeInfo.IPv4 -and ($probeInfo.IPv4 -notmatch '^169\.')) { 
                $connected = $true
                Log -msg "Manual WiFi connection detected: IP=$($probeInfo.IPv4)"
                break 
            }
            Start-Sleep -Seconds 3
            $wait += 3
        } while ($wait -lt 30)
    }
}

# 如果还是没有连接，尝试检测Portal页面是否可访问
if (-not $connected) {
    Log -msg "Testing portal accessibility..." -level "WARN"
    try {
        $portalTest = Invoke-WebRequest -Uri "http://172.29.0.2/" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($portalTest) {
            Log -msg "Portal accessible, assuming network is available" -level "WARN"
            $connected = $true
        }
    }
    catch {
        Log -msg "Portal not accessible either" -level "ERROR"
    }
}

if (-not $connected) {
    Log -msg "No network connection available" -level "ERROR"
    exit 1
}

# 获取网络信息
$info = Get-ActiveWifiInfo
if (-not $info -or -not $info.IPv4 -or ($info.IPv4 -match '^169\.')) {
    # 如果无法获取WiFi信息，尝试多次
    $retryCount = 0
    while ($retryCount -lt 3 -and (-not $info -or -not $info.IPv4 -or ($info.IPv4 -match '^169\.'))) {
        Start-Sleep -Milliseconds 800
        $info = Get-ActiveWifiInfo
        $retryCount++
    }
    
    if (-not $info -or -not $info.IPv4 -or ($info.IPv4 -match '^169\.')) {
        Log -msg "Cannot get valid WiFi info after retries, using placeholder" -level "WARN"
        $info = @{ IPv4="unknown"; MAC="unknown" }
    } else {
        Log -msg "Network info obtained after retry: IPv4=$($info.IPv4), MAC=$($info.MAC)"
    }
} else {
    Log -msg "Network: IPv4=$($info.IPv4), MAC=$($info.MAC)"
}

# 2) Captive portal check
$portal = Test-CaptivePortal -ProbeUrl $cfg.portal_probe_url
if ($portal) {
    Log -msg "Captive portal detection: $portal"
} else {
    Log -msg "Captive portal detection: UNKNOWN"
}

# 3) CDP page login
$pwdPlain = Load-Secret -Id $cfg.credential_id
if (-not $pwdPlain) {
    Log -msg "No saved password, run Save-Secret first" -level "ERROR"
    exit 1
}

# 计算本次 ISP（按 SSID 匹配覆盖）
$effectiveISP = $cfg.isp
try {
    $connectedSsid = (Get-LastWifiSuccess).ssid
    if ($connectedSsid -and $cfg.ssid_rules) {
        foreach ($rule in $cfg.ssid_rules) {
            $p = [string]$rule.pattern
            $matched = $false
            if ($p -match '^\^') { $matched = ($connectedSsid -match $p) }
            elseif ($p -match '[\*\?]') { $matched = ($connectedSsid -like $p) }
            else { $matched = ($connectedSsid -eq $p) }
            if ($matched) {
                if ($null -ne $rule.isp) { $effectiveISP = [string]$rule.isp }
                break
            }
        }
    }
} catch {}

# 转换ISP代码为中文名称（CDP函数需要中文名称）
$ispChinese = switch ($effectiveISP.ToLower()) {
    'unicom' { '中国联通'; break }
    'telecom' { '中国电信'; break }
    'cmcc' { '中国移动'; break }
    default { '中国联通' }  # 默认联通
}
Log -msg "ISP: $effectiveISP -> $ispChinese"

$portalUrl = $cfg.portal_probe_url
$entryUrl = $cfg.portal_entry_url
$ok = $false
try {
    $ok = Invoke-CDPAutofill -PortalUrl $portalUrl -EntryUrl $entryUrl -Username $cfg.username -Password $pwdPlain -ISP $ispChinese -Headless:$([bool]$cfg.headless) -Browser $cfg.browser
    if ($ok) {
        Log -msg "✅ CDP executed successfully, authentication likely succeeded"
    } else {
        Log -msg "⚠️ CDP executed but returned false, will verify network" -level "WARN"
    }
}
catch {
    $errMsg = $_.Exception.Message
    Log -msg ("❌ CDP execution failed: $errMsg") -level "ERROR"
}

# 若CDP返回成功，强制刷新网络状态并启动保活
if ($ok) {
    try {
        Log -msg "📡 正在刷新网络状态以完成认证..."
        
        # 先快速验证一次网络是否已经通
        $quickTest = $false
        try {
            $quickResponse = Invoke-WebRequest -Uri "http://www.gstatic.com/generate_204" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
            if ($quickResponse.StatusCode -eq 204) {
                $quickTest = $true
                Log -msg "✅ 网络已通，跳过刷新步骤"
            }
        } catch {}
        
        if (-not $quickTest) {
            # 网络还未通，执行刷新
            Log -msg "执行网络配置刷新..."
            try {
                # 刷新网络配置（更温和的方式）
                ipconfig /release | Out-Null
                Start-Sleep -Milliseconds 500
                ipconfig /renew | Out-Null
                Start-Sleep -Milliseconds 1000
            } catch {
                Log -msg "ipconfig刷新失败: $($_.Exception.Message)" -level "WARN"
            }
        }
        
        # 启动后台高频保活：10s/次，维持3分钟
        try {
            Import-Module "$root\modules\netdetect.psm1" -Force
            Start-Job -Name KeepAliveJob -ScriptBlock {
                Import-Module "$using:root\modules\netdetect.psm1" -Force
                Keep-AliveNetwork -IntervalSec 10 -MaxMinutes 3 | Out-Null
            } | Out-Null
            Log -msg "✅ 认证完成，已启动后台保活 (10秒间隔, 持续3分钟)" -level "SUCCESS"
        } catch {
            Log -msg "保活启动失败: $($_.Exception.Message)" -level "WARN"
        }
    } catch {
        Log -msg ("网络刷新异常: " + $_.Exception.Message) -level "WARN"
    }
    exit 0
}

# CDP返回false，等待认证生效后验证网络
Log -msg "⏳ 认证已提交，等待生效并验证网络连接..." -level "INFO"
Start-Sleep -Seconds 5  # 等待5秒，让eportal认证和页面刷新完成

$retries = 3
$netOk = $false
for ($i = 1; $i -le $retries; $i++) {
    $netOk = Test-Internet -TestUrl $cfg.test_url
    if ($netOk) {
        Log -msg ("✅ 网络验证成功 (第 $i 次尝试)") -level "SUCCESS"
        
        # 启动保活
        try {
            Import-Module "$root\modules\netdetect.psm1" -Force
            Start-Job -Name KeepAliveJob -ScriptBlock {
                Import-Module "$using:root\modules\netdetect.psm1" -Force
                Keep-AliveNetwork -IntervalSec 10 -MaxMinutes 3 | Out-Null
            } | Out-Null
            Log -msg "✅ 后台保活已启动 (10秒间隔, 持续3分钟)" -level "SUCCESS"
        } catch {}
        
        exit 0
    }
    if ($i -lt $retries) {
        Log -msg ("⏳ 第 $i 次验证未通过，3秒后重试...") -level "INFO"
        Start-Sleep -Seconds 3
    }
}

# 验证未通过但认证流程已完成，大概率已成功
if (-not $netOk) {
    Log -msg "⚠️ 网络验证超时，但认证流程已完成。若无法上网，请重新运行脚本" -level "WARN"
}
exit 0
