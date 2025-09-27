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
	return ($response.Content -match 'portal|login|认证|登录') ? 'PORTAL' : 'UNKNOWN'
}

function Test-Internet {
	param([string]$TestUrl='http://www.baidu.com')
	$response = Invoke-HttpRaw -Url $TestUrl -TimeoutSec 6
	if ($response -and $response.StatusCode -eq 200 -and $response.Content -notmatch 'portal|认证|登录') { return $true }
	return $false
}

Export-ModuleMember -Function Test-CaptivePortal,Test-Internet

