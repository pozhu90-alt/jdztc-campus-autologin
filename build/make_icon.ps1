param(
    [string]$PngPath = "..\dist\xiaoci_avatar.png",
    [string]$IcoPath = "..\dist\xiaoci_icon.ico"
)

Add-Type -AssemblyName System.Drawing

$pngFull = Resolve-Path $PngPath
$icoFull = Join-Path (Split-Path $pngFull) (Split-Path $IcoPath -Leaf)

try {
    $img = [System.Drawing.Bitmap]::FromFile($pngFull)
    $icon = [System.Drawing.Icon]::FromHandle($img.GetHicon())
    
    $file = New-Object System.IO.FileStream($icoFull, [System.IO.FileMode]::Create)
    $icon.Save($file)
    $file.Close()
    
    $img.Dispose()
    $icon.Dispose()
    
    Write-Host "Icon created: $icoFull" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

