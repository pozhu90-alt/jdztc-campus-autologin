function Start-Chromium {
    param([ValidateSet('edge','chrome')][string]$Browser='edge',[int]$Port=0,[switch]$Headless)
    $exe = $null
    $pf64 = $env:ProgramFiles
    $pf86 = ${env:ProgramFiles(x86)}
    $lad  = $env:LocalAppData
    if ($Browser -eq 'edge') {
        $candidates = @()
        if ($pf64) { $candidates += (Join-Path $pf64 'Microsoft\Edge\Application\msedge.exe') }
        if ($pf86) { $candidates += (Join-Path $pf86 'Microsoft\Edge\Application\msedge.exe') }
        if ($lad)  { $candidates += (Join-Path $lad  'Microsoft\Edge\Application\msedge.exe') }
    } else {
        $candidates = @()
        if ($pf64) { $candidates += (Join-Path $pf64 'Google\Chrome\Application\chrome.exe') }
        if ($pf86) { $candidates += (Join-Path $pf86 'Google\Chrome\Application\chrome.exe') }
        if ($lad)  { $candidates += (Join-Path $lad  'Google\Chrome\Application\chrome.exe') }
    }
    foreach ($p in $candidates) { if (Test-Path $p) { $exe = $p; break } }
    if (-not $exe) { return $null }
	if ($Port -eq 0) { $Port = Get-Random -Minimum 9222 -Maximum 9555 }
	$userData = Join-Path $env:TEMP ("portal_cdp_" + $Port)
	$browserArgs = @("--remote-debugging-port=$Port","--user-data-dir=$userData","--no-first-run","--no-default-browser-check","--disable-extensions")
	if ($Headless) { $browserArgs += @('--headless=new','--disable-gpu') }
	$psi = New-Object System.Diagnostics.ProcessStartInfo -Property @{ FileName=$exe; Arguments=($browserArgs -join ' '); UseShellExecute=$false; CreateNoWindow=$true }
    $proc = [System.Diagnostics.Process]::Start($psi)
    Write-Host ("🧭 使用浏览器可执行文件: " + $exe)
    Start-Sleep -Milliseconds 300
	return [pscustomobject]@{ Process=$proc; Port=$Port; UserDataDir=$userData }
}

function Get-CDPWebSocketUrl {
    param([int]$Port)
    for ($i=0;$i -lt 30;$i++){
		try{
            $ver = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/version" -TimeoutSec 2 -ErrorAction Stop
			if ($ver.webSocketDebuggerUrl) { return $ver.webSocketDebuggerUrl }
		}catch{}
        Start-Sleep -Milliseconds 200
	}
	return $null
}

function New-WebSocketClient {
	param([Parameter(Mandatory)][string]$Url)
	$client = [System.Net.WebSockets.ClientWebSocket]::new()
	$client.Options.KeepAliveInterval = [TimeSpan]::FromSeconds(20)
	$uri = [Uri]::new($Url)
	$client.ConnectAsync($uri,[Threading.CancellationToken]::None).Wait()
	return $client
}

function Send-CDPMessage {
	param(
		[System.Net.WebSockets.ClientWebSocket]$Client,
		[int]$Id,
		[string]$Method,
		[hashtable]$Params,
		[string]$SessionId
	)
	$base = @{ id=$Id; method=$Method; params=$Params }
	if ($SessionId) { $base['sessionId'] = $SessionId }
	$payload = $base | ConvertTo-Json -Depth 10
	$buffer = [ArraySegment[byte]]::new([Text.Encoding]::UTF8.GetBytes($payload))
	$Client.SendAsync($buffer,[System.Net.WebSockets.WebSocketMessageType]::Text,$true,[Threading.CancellationToken]::None).Wait()
}

function Receive-CDPMessage {
    param([System.Net.WebSockets.ClientWebSocket]$Client,[int]$TimeoutMs=5000)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $buffer = New-Object byte[] 65536
    $segment = [ArraySegment[byte]]::new($buffer)
    $stream = New-Object System.IO.MemoryStream
    try {
        while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
            if ($Client.State -ne 'Open') { break }
            # 尝试读取一帧，使用短超时轮询
            $tokenSrc = [Threading.CancellationTokenSource]::new()
            $tokenSrc.CancelAfter(200)
            try {
                $result = $Client.ReceiveAsync($segment,$tokenSrc.Token).GetAwaiter().GetResult()
            } catch {
                # 超时或暂无数据，继续轮询
                continue
            }
            if ($result.Count -gt 0) { $stream.Write($buffer,0,$result.Count) }
            if ($result.EndOfMessage -and $stream.Length -gt 0) {
                $json = [Text.Encoding]::UTF8.GetString($stream.ToArray())
                try { return $json | ConvertFrom-Json } catch { return $null }
            }
        }
        return $null
    } finally {
        $stream.Dispose()
    }
}

function Invoke-CDPAutofill {
	param(
		[string]$PortalUrl,
		[string]$EntryUrl,
		[string]$Username,
		[string]$Password,
		[string]$ISP='中国联通',
		[bool]$Headless=$true,
		[string]$Browser='edge'
	)

	Write-Host "🚀 开始CDP认证..."
	$chrome = Start-Chromium -Browser $Browser -Headless:($Headless) -Port 0
	if (-not $chrome) { 
		Write-Host "❌ 无法启动浏览器: $Browser"
		return $false 
	}
	
	try {
		$ws = Get-CDPWebSocketUrl -Port $chrome.Port
		if (-not $ws) { 
			Write-Host "❌ CDP 未就绪"
			return $false
		}
		
		Write-Host "✅ 浏览器启动成功，开始Portal认证..."
		$client = New-WebSocketClient -Url $ws
		$next=1

		# 检查WebSocket连接状态
		Write-Host "🔗 WebSocket状态: $($client.State)"
		
		# 允许发现新页面targets
		Send-CDPMessage -Client $client -Id ($next++) -Method 'Target.setDiscoverTargets' -Params @{ discover=$true }
		
		# 创建新页面（优先使用探测URL触发重定向，其次入口页）
		Write-Host "🎯 创建Portal页面..."
		# 强制只创建一个门户目标页：先关闭现有 page targets，再创建入口页
		try {
			Send-CDPMessage -Client $client -Id ($next++) -Method 'Target.getTargets' -Params @{}
			$pre = Receive-CDPMessage -Client $client -TimeoutMs 1500
			if ($pre -and $pre.result -and $pre.result.targetInfos) {
				$pages = $pre.result.targetInfos | Where-Object { $_.type -eq 'page' }
				foreach ($p in $pages) { Send-CDPMessage -Client $client -Id ($next++) -Method 'Target.closeTarget' -Params @{ targetId=$p.targetId } }
			}
			Start-Sleep -Milliseconds 200
		} catch {}
		$createId = $next++
		Send-CDPMessage -Client $client -Id $createId -Method 'Target.createTarget' -Params @{ url=$EntryUrl }
        Start-Sleep -Milliseconds 150

		# 优先从 createTarget 的结果中提取 targetId
		$createdTargetId = $null
		for ($ci=0; $ci -lt 10; $ci++) {
			$evt = Receive-CDPMessage -Client $client -TimeoutMs 200
			if (-not $evt) { continue }
			if ($evt.id -eq $createId -and $evt.result -and $evt.result.targetId) {
				$createdTargetId = $evt.result.targetId
				Write-Host ("✅ createTarget 返回 targetId: " + $createdTargetId)
				break
			}
			if ($evt.method -eq 'Target.targetCreated' -and $evt.params -and $evt.params.targetInfo -and $evt.params.targetInfo.type -eq 'page') {
				$ti = $evt.params.targetInfo
				if ($ti.url -match '172\.29\.0\.2' -or $ti.url -match 'a79\.htm' -or $ti.url -match '/eportal/' -or $ti.url -match 'portal') {
					$createdTargetId = $ti.targetId
					Write-Host ("✅ 从 targetCreated 事件捕获 targetId: " + $createdTargetId)
					break
				}
			}
		}

		# 等待Portal重定向完成
        Write-Host "⏳ 等待Portal重定向..."
        Start-Sleep -Milliseconds 200
		
		Write-Host "🔗 检查WebSocket状态: $($client.State)"
		$portalSessionId = $null
		$portalTargetId = $null
		# 优先使用 createTarget 返回的 targetId，减少一次 Target.getTargets
		if ($createdTargetId) {
			$portalTargetId = $createdTargetId
			Write-Host ("🎯 使用 createTarget 捕获的 targetId: " + $portalTargetId)
		} else {
			Write-Host "📋 请求目标列表..."
			$getTargetsId = $next++
			Send-CDPMessage -Client $client -Id $getTargetsId -Method 'Target.getTargets' -Params @{}
			$targetsResp = Receive-CDPMessage -Client $client -TimeoutMs 2000
			if ($targetsResp -and $targetsResp.result -and $targetsResp.result.targetInfos) {
				$pageTargets = $targetsResp.result.targetInfos | Where-Object { $_.type -eq 'page' }
				foreach ($target in $pageTargets) {
					if ($target.url -match '172\.29\.0\.2' -or $target.url -match 'a79\.htm' -or $target.url -match '/eportal/' -or $target.url -match 'portal' -or $target.url -match 'userip=' -or $target.url -match 'wlanacip=') { $portalTargetId = $target.targetId; break }
				}
			}
		}

		if (-not $portalTargetId) { 
			Write-Host "❌ 无法找到Portal页面target，尝试fallback策略..." -ForegroundColor Yellow
			
			# Fallback 1: 尝试直接使用HTTP请求检查targets
			try {
				Write-Host "🔄 Fallback: 通过HTTP API获取targets..."
				$httpTargets = Invoke-RestMethod -Uri "http://127.0.0.1:$($chrome.Port)/json/list" -TimeoutSec 3
				Write-Host "📋 HTTP API返回的targets: $($httpTargets | ConvertTo-Json -Depth 2 -Compress)"
				
				foreach ($target in $httpTargets) {
					if ($target.url -match '172\.29\.0\.2' -or $target.url -match 'a79\.htm') {
						$portalTargetId = $target.id
						Write-Host "✅ 通过HTTP API找到Portal target: $portalTargetId"
						break
					}
				}
			} catch {
				Write-Host "❌ HTTP API fallback失败: $($_.Exception.Message)" -ForegroundColor Red
			}
		}
		
		if (-not $portalTargetId) { 
			Write-Host "❌ 所有方法都无法找到Portal页面target，认证失败" -ForegroundColor Red
			return $false
		}

		# 连接到target
		Write-Host "🔗 连接到target: $portalTargetId"
		$attachId = $next++
		Send-CDPMessage -Client $client -Id $attachId -Method 'Target.attachToTarget' -Params @{ targetId=$portalTargetId; flatten=$true }
		
		# 等待正确的attachToTarget响应 - 可能需要接收多个消息
		$portalSessionId = $null
		$maxAttempts = 5
		for ($i = 0; $i -lt $maxAttempts; $i++) {
			$attach = Receive-CDPMessage -Client $client -TimeoutMs 2000
			if (-not $attach) { break }
			
			Write-Host "📡 收到响应 $($i+1): $($attach | ConvertTo-Json -Depth 2 -Compress)" -ForegroundColor Cyan
			
			# 检查是否是Target.attachedToTarget事件（params格式）
			if ($attach.method -eq 'Target.attachedToTarget' -and $attach.params -and $attach.params.sessionId) {
				$portalSessionId = $attach.params.sessionId
				Write-Host "✅ 从事件中提取sessionId: $portalSessionId" -ForegroundColor Green
				break
			}
			
			# 检查是否是attachToTarget的结果响应（result格式）
			if ($attach.id -eq $attachId -and $attach.result -and $attach.result.sessionId) {
				$portalSessionId = $attach.result.sessionId
				Write-Host "✅ 从结果中提取sessionId: $portalSessionId" -ForegroundColor Green
				break
			}
		}

		if (-not $portalSessionId) {
			Write-Host "❌ 未能获取sessionId" -ForegroundColor Red
			Write-Host "🔄 尝试Fallback: 使用非扁平会话进行attach..." -ForegroundColor Yellow
			# Fallback: flatten=false 再次尝试获取 sessionId
			$attachId2 = $next++
			Send-CDPMessage -Client $client -Id $attachId2 -Method 'Target.attachToTarget' -Params @{ targetId=$portalTargetId; flatten=$false }
			for ($j = 0; $j -lt 20; $j++) {
				$attach2 = Receive-CDPMessage -Client $client -TimeoutMs 500
				if (-not $attach2) { continue }
				Write-Host "📡 [fallback] 收到响应 $($j+1): $($attach2 | ConvertTo-Json -Depth 2 -Compress)" -ForegroundColor Cyan
				if ($attach2.method -eq 'Target.attachedToTarget' -and $attach2.params -and $attach2.params.sessionId) {
					$portalSessionId = $attach2.params.sessionId
					break
				}
				if ($attach2.id -eq $attachId2 -and $attach2.result -and $attach2.result.sessionId) {
					$portalSessionId = $attach2.result.sessionId
					break
				}
			}
			if (-not $portalSessionId) {
				Write-Host "❌ 仍未能获取sessionId，放弃" -ForegroundColor Red
				return $false
			}
		}
		Write-Host "✅ Portal会话建立成功: $portalSessionId"

		# 启用必要的域，提升可观测性与稳定性
		foreach ($m in @('Page.enable','Runtime.enable','Network.enable')){
			Send-CDPMessage -Client $client -Id ($next++) -Method $m -Params @{} -SessionId $portalSessionId
		}
		Send-CDPMessage -Client $client -Id ($next++) -Method 'Page.setLifecycleEventsEnabled' -Params @{ enabled = $true } -SessionId $portalSessionId

		# 不刷新，直接注入，随后按需再次刷新登录一次（符合你的手动步骤）
		Write-Host "⚡ 跳过首次刷新，直接注入登录脚本"

		# 若当前URL与入口差异较大，尝试导航
		$evalUrlId = $next++
		Send-CDPMessage -Client $client -Id $evalUrlId -Method 'Runtime.evaluate' -Params @{ expression='location.href'; returnByValue=$true } -SessionId $portalSessionId
		$__href = $null
        for ($ti=0; $ti -lt 5; $ti++) {
            $__msg = Receive-CDPMessage -Client $client -TimeoutMs 200
			if ($__msg -and $__msg.id -eq $evalUrlId) { $__href = $__msg; break }
		}
		$__cur = if ($__href -and $__href.result -and $__href.result.result) { $__href.result.result.value } else { '' }
		if ($EntryUrl -and $__cur -and ($__cur -notmatch '172\.29\.0\.2|a79\.htm|/eportal/|portal')) {
			Write-Host ("🔄 当前URL: " + $__cur + "，尝试导航到入口: " + $EntryUrl)
            Send-CDPMessage -Client $client -Id ($next++) -Method 'Page.navigate' -Params @{ url=$EntryUrl } -SessionId $portalSessionId
            Start-Sleep -Milliseconds 600
		}

		# 注入自动填充脚本
		Write-Host "📝 注入自动填充脚本..."
		$scriptPathCandidates = @()
		$scriptPathCandidates += (Join-Path (Split-Path $PSScriptRoot -Parent) 'portal_autofill\autofill_core.js')
		$scriptPathCandidates += (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'portal_autofill\autofill_core.js')
		$scriptPathCandidates += (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\portal_autofill\autofill_core.js')
		$scriptPathCandidates += (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'scripts\portal_autofill\autofill_core.js')
		$scriptPath = $null
		foreach ($c in $scriptPathCandidates) { if (Test-Path $c) { $scriptPath = $c; break } }
		if (-not $scriptPath) {
			Write-Host "❌ 未找到脚本文件，已尝试:"
			foreach ($c in $scriptPathCandidates) { Write-Host ("   - " + $c) }
			return $false
		}
		Write-Host ("📄 使用脚本: " + $scriptPath)

		$workingScript = Get-Content $scriptPath -Raw -Encoding UTF8
		$jsConfig = @{
			username = $Username
			password = $Password
			isp = $ISP
			delayMs = 200
		}
		$jsonConfig = $jsConfig | ConvertTo-Json -Compress
		$finalExpression = "($workingScript)($jsonConfig)"

		Write-Host "🚀 执行脚本..."
		$evalId = $next++
		Send-CDPMessage -Client $client -Id $evalId -Method 'Runtime.evaluate' -Params @{ expression=$finalExpression; returnByValue=$true; awaitPromise=$true; userGesture=$true } -SessionId $portalSessionId
        # 等待注入执行结果
        $result = $null
        for ($ri=0; $ri -lt 12; $ri++) {
            $msg = Receive-CDPMessage -Client $client -TimeoutMs 200
			if (-not $msg) { continue }
			if ($msg.id -eq $evalId) { $result = $msg; break }
		}
		# 单次注入，纯模拟人工

		if ($result -and $result.result) {
			if ($result.result.exceptionDetails) {
				Write-Host "❌ 脚本执行异常:" -ForegroundColor Red
				if ($result.result.exceptionDetails.exception -and $result.result.exceptionDetails.exception.description) {
					Write-Host "   $($result.result.exceptionDetails.exception.description)" -ForegroundColor Red
				} else {
					Write-Host ("   " + ($result.result.exceptionDetails | ConvertTo-Json -Depth 2 -Compress)) -ForegroundColor Red
				}
			} elseif ($result.result.result -and $result.result.result.value) {
				$scriptResult = $result.result.result.value
				Write-Host "✅ 脚本执行成功！" -ForegroundColor Green
				
				# 显示脚本执行的详细信息
				if ($scriptResult.log) {
					Write-Host "📋 脚本执行日志:" -ForegroundColor Yellow
					foreach ($logEntry in $scriptResult.log) {
						Write-Host "   $logEntry" -ForegroundColor Cyan
					}
				}
				
				if ($scriptResult.pageStructure) {
				Write-Host "📊 页面结构:" -ForegroundColor Yellow
					Write-Host "   输入框: $($scriptResult.pageStructure.inputs.Count)" -ForegroundColor Cyan
					Write-Host "   按钮: $($scriptResult.pageStructure.buttons.Count)" -ForegroundColor Cyan
					Write-Host "   选择框: $($scriptResult.pageStructure.selects.Count)" -ForegroundColor Cyan
				}
				
				Write-Host "🎯 执行结果:" -ForegroundColor Yellow
				Write-Host ("   用户名字段: " + $(if ($scriptResult.userField) { $scriptResult.userField } else { '未找到' })) -ForegroundColor Cyan
				Write-Host ("   密码字段: " + $(if ($scriptResult.pwdField) { $scriptResult.pwdField } else { '未找到' })) -ForegroundColor Cyan
				Write-Host ("   运营商字段: " + $(if ($scriptResult.ispField) { $scriptResult.ispField } else { '未找到' })) -ForegroundColor Cyan
				Write-Host ("   登录点击: " + $(if ($scriptResult.clicked) { '✅成功' } else { '❌失败' })) -ForegroundColor $(if ($scriptResult.clicked) { 'Green' } else { 'Red' })
				if ($scriptResult.success) { Write-Host "   成功信号: ✅ 检测到" -ForegroundColor Green }

				# 已在前面执行过刷新与二次注入
			} else {
				Write-Host "⚠️ 脚本执行返回空结果" -ForegroundColor Yellow
			}
		} else {
			Write-Host "⚠️ 脚本执行无响应" -ForegroundColor Yellow
		}

		# 给二次登录预留时间，避免页面尚未提交就被关闭
        Write-Host "⏳ 等待二次登录完成..."
        Start-Sleep -Milliseconds 1000

		# 关闭门户页面/浏览器
		Write-Host "🧹 关闭门户页面..."
		try {
			# 直接关闭所有 page targets，确保所有门户页/窗口都被关闭
			Send-CDPMessage -Client $client -Id ($next++) -Method 'Target.getTargets' -Params @{}
			$resp = Receive-CDPMessage -Client $client -TimeoutMs 1500
			if ($resp -and $resp.result -and $resp.result.targetInfos) {
				$pages = $resp.result.targetInfos | Where-Object { $_.type -eq 'page' }
				foreach ($p in $pages) {
					Send-CDPMessage -Client $client -Id ($next++) -Method 'Target.closeTarget' -Params @{ targetId=$p.targetId }
				}
			}
		} catch {}

		# 结合页面脚本返回与快速外网探测，判断是否成功
		$__finalOk = $false
		try {
			if ($result -and $result.result -and $result.result.result -and $result.result.result.value) {
				$__r = $result.result.result.value
				if ($__r.success) { $__finalOk = $true }
			}
		} catch {}
		if (-not $__finalOk) {
			try {
				$__probe = Invoke-WebRequest -Uri 'http://www.gstatic.com/generate_204' -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
				if ($__probe -and ($__probe.StatusCode -eq 204 -or ($__probe.StatusCode -eq 200 -and ($__probe.Content -notmatch 'portal|认证|登录')))) { $__finalOk = $true }
			} catch {}
		}
		if ($__finalOk) { Write-Host "✅ CDP认证流程完成" } else { Write-Host "⚠️ 未检测到明确成功，返回失败以启用后续网络重试" }
		return $__finalOk

	} catch {
		Write-Host "❌ CDP认证异常: $($_.Exception.Message)" -ForegroundColor Red
		return $false
	} finally {
		try { 
			if ($client) { $client.Dispose() } 
		} catch {}
		try { if ($chrome.Process) { $chrome.Process.Kill() | Out-Null } } catch {}
		try { 
			if (Test-Path $chrome.UserDataDir) { Remove-Item $chrome.UserDataDir -Recurse -Force -ErrorAction SilentlyContinue } 
		} catch {}
		# 兜底：关闭系统层面可能残留的门户窗口（非本会话创建）
		try {
			$names = @('msedge','chrome')
			$patterns = '上网登录|网络认证|eportal|portal|172\.29\.0\.2|a79\.htm'
			foreach ($n in $names) {
				Get-Process -Name $n -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -match $patterns } | ForEach-Object { $_ | Stop-Process -Force -ErrorAction SilentlyContinue }
			}
		} catch {}
	}
}

Export-ModuleMember -Function Invoke-CDPAutofill
