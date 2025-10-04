# Convert PNG to ICO for exe icon
param(
    [string]$PngPath,
    [string]$IcoPath
)

Add-Type -AssemblyName System.Drawing

try {
    # Load PNG image
    $img = [System.Drawing.Image]::FromFile($PngPath)
    
    # Create icon from image
    $icon = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]$img).GetHicon())
    
    # Save as ICO
    $fs = New-Object System.IO.FileStream($IcoPath, [System.IO.FileMode]::Create)
    $icon.Save($fs)
    $fs.Close()
    
    Write-Host "Icon converted successfully: $IcoPath" -ForegroundColor Green
    return $true
} catch {
    Write-Host "Icon conversion failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
}

