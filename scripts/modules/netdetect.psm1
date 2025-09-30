function Invoke-HttpRaw {
	param([string]$Url,[int]$TimeoutSec=5,[switch]$NoRedirect)
	try{
		$opt = @{Uri=$Url;TimeoutSec=$TimeoutSec;UseBasicParsing=$true;ErrorAction='SilentlyContinue'}
		if ($NoRedirect) { $opt.MaximumRedirection=0 }
		return Invoke-WebRequest @opt
	}catch{ return $null }
}

function Test-CaptivePortal {
	param([string]$ProbeUrl='http://www.gstatic.com/generate_204')
	# 不跟随重定向，若返回非 204/被重定向，视为被门户劫持
	$response = Invoke-HttpRaw -Url $ProbeUrl -TimeoutSec 5 -NoRedirect
	if (-not $response) { return 'UNKNOWN' }
	if ($response.StatusCode -ge 300 -and $response.StatusCode -lt 400) { return 'PORTAL' }
	if ($response.StatusCode -eq 204) { return 'OPEN' }
	if ($response.Content -match 'portal|login|认证|登录') { return 'PORTAL' } else { return 'UNKNOWN' }
}

function Test-Internet {
	param([string]$TestUrl='http://www.baidu.com')
	
	# 首先尝试NCSI检测URL，这个校园网通常会优先放行
	try {
		$ncsiResponse = Invoke-HttpRaw -Url 'http://www.gstatic.com/generate_204' -TimeoutSec 4
		if ($ncsiResponse -and $ncsiResponse.StatusCode -eq 204) { 
			return $true 
		}
	} catch {}
	
	# 如果NCSI失败，再尝试用户指定的测试URL
	$response = Invoke-HttpRaw -Url $TestUrl -TimeoutSec 6
	if ($response -and $response.StatusCode -eq 200 -and $response.Content -notmatch 'portal|认证|登录') { 
		return $true 
	}
	return $false
}

Export-ModuleMember -Function Test-CaptivePortal,Test-Internet


# 高频后台保活：周期性对外探测，防止Portal会话超时
function Keep-AliveNetwork {
    param(
        [int]$IntervalSec = 45,
        [int]$MaxMinutes = 8,
        [string]$ProbeUrl = 'http://www.gstatic.com/generate_204',
        [string]$AltUrl = 'http://www.baidu.com'
    )
    try {
        $deadline = (Get-Date).AddMinutes($MaxMinutes)
        while ((Get-Date) -lt $deadline) {
            try {
                $ok1 = $false; $ok2 = $false
                
                # 主要探测：NCSI检测URL
                try { 
                    $r1 = Invoke-HttpRaw -Url $ProbeUrl -TimeoutSec 4
                    if ($r1 -and ($r1.StatusCode -eq 204 -or $r1.StatusCode -eq 200)) { $ok1 = $true } 
                } catch {}
                
                # 备用探测：外网访问测试
                if (-not $ok1) { 
                    try { 
                        $r2 = Invoke-HttpRaw -Url $AltUrl -TimeoutSec 5
                        if ($r2 -and $r2.StatusCode -eq 200) { $ok2 = $true } 
                    } catch {} 
                }
                
            } catch {}
            
            # 确保间隔时间合理（最小5秒，避免过于频繁）
            $actualInterval = [Math]::Max(5, [int]$IntervalSec)
            Start-Sleep -Seconds $actualInterval
        }
    } catch {}
}

Export-ModuleMember -Function Keep-AliveNetwork -Force
