# 小瓷连网 - 完整构建脚本（含图标转换）
param(
    [switch]$Blank
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root = Split-Path $PSScriptRoot -Parent
$build = $PSScriptRoot
$dist = Join-Path $root 'dist'

Write-Host "`n=== 小瓷连网 构建脚本 ===" -ForegroundColor Cyan
Write-Host ""

# 1. 检查并转换图标
$avatarPng = Join-Path $dist 'xiaoci_avatar.png'
$iconIco = Join-Path $dist 'xiaoci_icon.ico'

if (Test-Path $avatarPng) {
    Write-Host "✓ 找到头像图片: xiaoci_avatar.png" -ForegroundColor Green
    
    # 使用 .NET 转换 PNG 到 ICO
    try {
        Add-Type -AssemblyName System.Drawing
        
        # 读取PNG
        $img = [System.Drawing.Image]::FromFile($avatarPng)
        
        # 创建多尺寸ICO（256x256, 128x128, 64x64, 48x48, 32x32, 16x16）
        $sizes = @(256, 128, 64, 48, 32, 16)
        $ms = New-Object System.IO.MemoryStream
        $bw = New-Object System.IO.BinaryWriter($ms)
        
        # ICO header
        $bw.Write([UInt16]0)  # Reserved
        $bw.Write([UInt16]1)  # Image type (1 = ICO)
        $bw.Write([UInt16]$sizes.Count)  # Number of images
        
        $imageDataList = @()
        $offset = 6 + ($sizes.Count * 16)  # Header + directory entries
        
        foreach ($size in $sizes) {
            # Resize image
            $resized = New-Object System.Drawing.Bitmap($size, $size)
            $graphics = [System.Drawing.Graphics]::FromImage($resized)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($img, 0, 0, $size, $size)
            $graphics.Dispose()
            
            # Convert to PNG byte array
            $pngStream = New-Object System.IO.MemoryStream
            $resized.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
            $pngBytes = $pngStream.ToArray()
            $pngStream.Dispose()
            $resized.Dispose()
            
            # Write directory entry
            $bw.Write([byte]$size)  # Width
            $bw.Write([byte]$size)  # Height
            $bw.Write([byte]0)      # Color palette
            $bw.Write([byte]0)      # Reserved
            $bw.Write([UInt16]1)    # Color planes
            $bw.Write([UInt16]32)   # Bits per pixel
            $bw.Write([UInt32]$pngBytes.Length)  # Image size
            $bw.Write([UInt32]$offset)  # Image offset
            
            $imageDataList += $pngBytes
            $offset += $pngBytes.Length
        }
        
        # Write image data
        foreach ($imageData in $imageDataList) {
            $bw.Write($imageData)
        }
        
        # Save ICO file
        [System.IO.File]::WriteAllBytes($iconIco, $ms.ToArray())
        
        $bw.Close()
        $ms.Close()
        $img.Dispose()
        
        Write-Host "✓ 图标转换成功: xiaoci_icon.ico" -ForegroundColor Green
    } catch {
        Write-Host "⚠ 图标转换失败: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  将继续构建（不使用自定义图标）" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ 未找到头像图片: $avatarPng" -ForegroundColor Yellow
    Write-Host "  请将图片保存为: dist\xiaoci_avatar.png" -ForegroundColor Yellow
    Write-Host "  将继续构建（不使用自定义图标）" -ForegroundColor Yellow
}

Write-Host ""

# 2. 调用主构建脚本
$makeScript = Join-Path $build 'make_ps2exe_obf.ps1'
$outputName = if ($Blank) { '小瓷连网_空白版.exe' } else { '小瓷连网.exe' }

Write-Host "开始构建: $outputName" -ForegroundColor Cyan

if ($Blank) {
    & $makeScript -OutputName $outputName -Blank
} else {
    & $makeScript -OutputName $outputName
}

Write-Host ""
Write-Host "=== 构建完成 ===" -ForegroundColor Green

