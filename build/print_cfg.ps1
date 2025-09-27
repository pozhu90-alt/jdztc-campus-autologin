$p = Join-Path $env:APPDATA 'CampusNet\config.json'
if (-not (Test-Path -LiteralPath $p)) { Write-Output "MISSING: $p"; exit }
$j = Get-Content -LiteralPath $p -Raw -Encoding UTF8
try { $cfg = $j | ConvertFrom-Json } catch { Write-Output "JSON_ERROR: $($_.Exception.Message)"; exit 1 }
Write-Output ("username=" + [string]$cfg.username)
Write-Output ("isp=" + [string]$cfg.isp)
Write-Output ("browser=" + [string]$cfg.browser)
Write-Output ("min_signal_percent=" + [string]$cfg.min_signal_percent)
Write-Output ("wifi_names.count=" + ([int](@($cfg.wifi_names).Count)))

