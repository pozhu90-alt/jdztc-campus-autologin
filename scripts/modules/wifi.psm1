function Start-WlanService { Start-Service -Name WlanSvc -ErrorAction SilentlyContinue }

function Enable-WifiAdapter {
	try {
		$wifi = Get-NetAdapter | Where-Object { $_.Status -ne 'Up' -and ($_.Name -match 'Wi-?Fi|Wireless|802\.11') } | Select-Object -First 1
		if ($wifi) { Enable-NetAdapter -Name $wifi.Name -Confirm:$false -ErrorAction SilentlyContinue }
	} catch {}
}

function Ensure-OpenProfile {
	param([Parameter(Mandatory)][string]$Ssid)
	$xml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
	<name>$Ssid</name>
	<SSIDConfig><SSID><name>$Ssid</name></SSID></SSIDConfig>
	<connectionType>ESS</connectionType>
	<connectionMode>auto</connectionMode>
	<MSM>
		<security>
			<authEncryption><authentication>open</authentication><encryption>none</encryption><useOneX>false</useOneX></authEncryption>
		</security>
	</MSM>
</WLANProfile>
"@
	$path = [System.IO.Path]::GetTempFileName().Replace('.tmp','.xml')
	$xml | Out-File -FilePath $path -Encoding UTF8 -Force
	cmd /c "netsh wlan add profile filename=`"$path`" user=all" | Out-Null
	Remove-Item $path -Force -ErrorAction SilentlyContinue
}

function Connect-Wifi {
    param([string[]]$WifiNames,[int]$TimeoutSec=20)
	Start-WlanService
	Enable-WifiAdapter
	foreach ($ssid in $WifiNames) {
		Ensure-OpenProfile -Ssid $ssid
        cmd /c "netsh wlan connect name=`"$ssid`"" | Out-Null
		$sw = [Diagnostics.Stopwatch]::StartNew()
		while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
			$iface = cmd /c "netsh wlan show interfaces" 2>$null
			if ($iface -match $ssid -and $iface -match '已连接|connected') { return $true }
			Start-Sleep -Milliseconds 800
		}
	}
	return $false
}

function Get-ActiveWifiInfo {
	$iface = cmd /c "netsh wlan show interfaces" 2>$null
	if (-not $iface -or $iface -notmatch '已连接|connected') { return $null }
	$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -match 'Wi-?Fi|Wireless' -and $_.IPAddress -notmatch '^169\.' } | Select-Object -First 1).IPAddress
	$mac = (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Name -match 'Wi-?Fi|Wireless' } | Select-Object -First 1).MacAddress
	if (-not $ip) { return $null }
	return [pscustomobject]@{ IPv4=$ip; MAC=$mac }
}

Export-ModuleMember -Function Connect-Wifi,Get-ActiveWifiInfo

# ======== 新增：快速扫描与智能连接 ========
function Scan-WifiNetworks {
    $raw = cmd /c "netsh wlan show networks mode=bssid" 2>$null
    if (-not $raw) { return @() }
    $lines = $raw -split "`r?`n"
    $results = @()
    $currentSsid = $null
    foreach ($l in $lines) {
        if ($l -match '^\s*SSID\s+\d+\s*:\s*(.+)$') {
            $currentSsid = ($Matches[1]).Trim()
        } elseif ($currentSsid -and $l -match 'Signal\s*:\s*(\d+)%') {
            $sig = [int]$Matches[1]
            $prev = $results | Where-Object { $_.Ssid -eq $currentSsid } | Select-Object -First 1
            if ($prev) { if ($sig -gt $prev.Signal) { $prev.Signal = $sig } }
            else { $results += [pscustomobject]@{ Ssid=$currentSsid; Signal=$sig } }
        }
    }
    return $results
}

function Get-LastWifiSuccess {
    $path = Join-Path $PSScriptRoot '..\..\wifi_state.json'
    if (Test-Path $path) {
        try { return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

function Set-LastWifiSuccess {
    param([Parameter(Mandatory)][string]$Ssid)
    $path = Join-Path $PSScriptRoot '..\..\wifi_state.json'
    $obj = @{ ssid=$Ssid; ts=[DateTime]::UtcNow.ToString('o') }
    try { ($obj | ConvertTo-Json -Depth 5) | Out-File -FilePath $path -Encoding UTF8 -Force } catch {}
}

function Select-WifiCandidate {
    param([string[]]$WifiNames,[int]$SignalMargin=10)
    $scan = Scan-WifiNetworks
    if (-not $scan -or $scan.Count -eq 0) { return $null }
    $cands = @()
    foreach ($n in $WifiNames) {
        $hit = $scan | Where-Object {
            if ($n -match '^\^') { $_.Ssid -match $n }           # 正则（以 ^ 开头）
            elseif ($n -match '[\*\?]') { $_.Ssid -like $n }    # 通配符（含 * 或 ?）
            else { $_.Ssid -eq $n }                               # 精确匹配
        } | Sort-Object Signal -Descending | Select-Object -First 1
        if ($hit) { $cands += $hit }
    }
    if ($cands.Count -eq 0) { return $null }
    if ($cands.Count -eq 1) { return $cands[0].Ssid }
    $a = $cands | Sort-Object Signal -Descending
    $best = $a[0]
    $second = $a[1]
    $last = Get-LastWifiSuccess
    if ($second -and ([int]$best.Signal - [int]$second.Signal) -lt $SignalMargin -and $last -and $cands.Ssid -contains $last.ssid) {
        return $last.ssid
    }
    return $best.Ssid
}

function Connect-WifiSmart {
    param([string[]]$WifiNames,[int]$QuickWaitSec=3,[int]$SignalMargin=10)
    Start-WlanService; Enable-WifiAdapter
    $chosen = Select-WifiCandidate -WifiNames $WifiNames -SignalMargin $SignalMargin
    if (-not $chosen) { return $false }
    Ensure-OpenProfile -Ssid $chosen
    cmd /c "netsh wlan connect name=`"$chosen`"" | Out-Null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $QuickWaitSec) {
        $iface = cmd /c "netsh wlan show interfaces" 2>$null
        if ($iface -match $chosen -and $iface -match '已连接|connected') { Set-LastWifiSuccess -Ssid $chosen; return $true }
        Start-Sleep -Milliseconds 200
    }
    # 连接不立即成功则尝试另一候选（若有）
    $alt = ($WifiNames | Where-Object { $_ -ne $chosen })
    foreach ($ssid in $alt) {
        if (-not ($scan | Where-Object { $_.Ssid -eq $ssid })) { continue }
        Ensure-OpenProfile -Ssid $ssid
        cmd /c "netsh wlan connect name=`"$ssid`"" | Out-Null
        $sw.Restart()
        while ($sw.Elapsed.TotalSeconds -lt $QuickWaitSec) {
            $iface = cmd /c "netsh wlan show interfaces" 2>$null
            if ($iface -match $ssid -and $iface -match '已连接|connected') { Set-LastWifiSuccess -Ssid $ssid; return $true }
            Start-Sleep -Milliseconds 200
        }
    }
    return $false
}

Export-ModuleMember -Function Connect-WifiSmart,Scan-WifiNetworks,Select-WifiCandidate,Get-LastWifiSuccess,Set-LastWifiSuccess

