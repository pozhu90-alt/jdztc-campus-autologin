$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot '..\dist\config_gui.ps1'
$tokens = $null
$errors = $null
$lines = Get-Content -Path $path
[void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors -and $errors.Count -gt 0) {
    foreach ($e in $errors) {
        $ln = $e.Extent.StartLineNumber
        $col = $e.Extent.StartColumnNumber
        $start = [Math]::Max(1, $ln-2)
        $end = [Math]::Min($lines.Count, $ln+2)
        Write-Output ("ERROR: {0} @ line {1}, column {2}" -f $e.Message, $ln, $col)
        for ($i=$start; $i -le $end; $i++) { Write-Output ("{0}: {1}" -f $i, $lines[$i-1]) }
        Write-Output '-----'
    }
} else {
    Write-Output 'OK'
}

