# Campus Network GUI Admin Launcher
# Solves permission issues for task creation

param()

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Get current script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$guiScript = Join-Path $scriptDir 'config_gui_new.ps1'

if (-not (Test-Path $guiScript)) {
    Write-Host "Error: config_gui_new.ps1 file not found" -ForegroundColor Red
    Read-Host "Press any key to exit"
    exit 1
}

if (Test-Administrator) {
    Write-Host "Admin privileges confirmed. Starting GUI..." -ForegroundColor Green
    # Run GUI directly
    & $guiScript
} else {
    Write-Host "Administrator privileges required for system tasks" -ForegroundColor Yellow
    Write-Host "Requesting admin privileges..." -ForegroundColor Yellow
    
    try {
        # Restart with admin privileges
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$guiScript`""
        Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Verb RunAs
        Write-Host "Admin GUI started successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to start with admin privileges: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please manually right-click PowerShell, select 'Run as Administrator', then execute:" -ForegroundColor Yellow
        Write-Host "    .\dist\config_gui_new.ps1" -ForegroundColor Cyan
        Read-Host "Press any key to exit"
    }
}
