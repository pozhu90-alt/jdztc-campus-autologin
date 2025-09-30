function Save-Secret {
	param(
		[Parameter(Mandatory)][string]$Id,
		[Parameter(Mandatory)][securestring]$Secret
	)
	# 使用 PowerShell 内置 DPAPI（当前用户范围）
	$enc = ConvertFrom-SecureString -SecureString $Secret
	$path = Join-Path -Path $PSScriptRoot -ChildPath "..\..\secrets.json"

	# 兼容：若已存在文件被解析为 PSCustomObject，则转为可索引 hashtable
	$raw = $null
	try {
		if (Test-Path $path) { $raw = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json }
	} catch {}
	$data = [ordered]@{}
	if ($raw) {
		if ($raw -is [hashtable]) { $data = $raw }
		else {
			foreach ($p in $raw.PSObject.Properties) { $data[$p.Name] = $p.Value }
		}
	}
	$data[$Id] = $enc
	($data | ConvertTo-Json -Depth 10) | Out-File -FilePath $path -Encoding UTF8 -Force
	return $true
}

function Remove-Secret {
    param([Parameter(Mandatory)][string]$Id)
    $path = Join-Path -Path $PSScriptRoot -ChildPath "..\..\secrets.json"
    if (-not (Test-Path $path)) { return $true }
    try {
        $raw = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        $data = [ordered]@{}
        if ($raw) {
            foreach ($p in $raw.PSObject.Properties) { if ($p.Name -ne $Id) { $data[$p.Name] = $p.Value } }
        }
        ($data | ConvertTo-Json -Depth 10) | Out-File -FilePath $path -Encoding UTF8 -Force
        return $true
    } catch { return $false }
}
function Load-Secret {
	param([Parameter(Mandatory)][string]$Id)
	$path = Join-Path -Path $PSScriptRoot -ChildPath "..\..\secrets.json"
	
	# 尝试从用户DPAPI读取
	if (Test-Path $path) {
		try {
			$data = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
			$cipher = $data.$Id
			if ($cipher) {
				$sec = ConvertTo-SecureString -String $cipher
				# 解密成明文（仅用于内存传递给 CDP 注入）
				$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
				try { return [Runtime.InteropServices.Marshal]::PtrToStringUni($bstr) }
				finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
			}
		} catch {
			# DPAPI解密失败，可能是SYSTEM账号尝试读取用户加密的数据
		}
	}
	
	# 如果DPAPI读取失败，尝试从用户级存储读取
	try {
		$userSecretPath = Join-Path $env:APPDATA 'CampusNet\user_secrets.json'
		if (Test-Path $userSecretPath) {
			$userData = Get-Content $userSecretPath -Raw -Encoding UTF8 | ConvertFrom-Json
			$encoded = $userData.$Id
			if ($encoded) {
				# 解码Base64
				$plainBytes = [Convert]::FromBase64String($encoded)
				return [Text.Encoding]::UTF8.GetString($plainBytes)
			}
		}
	} catch {}
	
	# 如果用户级存储也失败，尝试临时存储
	try {
		$tempSecretPath = Join-Path $env:TEMP 'CampusNet_user_secrets.json'
		if (Test-Path $tempSecretPath) {
			$tempData = Get-Content $tempSecretPath -Raw -Encoding UTF8 | ConvertFrom-Json
			$encoded = $tempData.$Id
			if ($encoded) {
				# 解码Base64
				$plainBytes = [Convert]::FromBase64String($encoded)
				return [Text.Encoding]::UTF8.GetString($plainBytes)
			}
		}
	} catch {}
	
	# 最后尝试从系统级存储读取（向后兼容）
	try {
		$systemSecretPath = Join-Path $env:ProgramData 'CampusNet\system_secrets.json'
		if (Test-Path $systemSecretPath) {
			$systemData = Get-Content $systemSecretPath -Raw -Encoding UTF8 | ConvertFrom-Json
			$encoded = $systemData.$Id
			if ($encoded) {
				# 解码Base64
				$plainBytes = [Convert]::FromBase64String($encoded)
				return [Text.Encoding]::UTF8.GetString($plainBytes)
			}
		}
	} catch {}
	
	return $null
}

Export-ModuleMember -Function Save-Secret,Load-Secret,Remove-Secret

