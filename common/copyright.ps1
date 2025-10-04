# 版权保护模块
# Copyright (C) 2025 [你的名字]
# Licensed under GNU GPL v3

function Show-Copyright {
    param(
        [switch]$ShowDialog
    )
    
    $copyrightInfo = @"
╔══════════════════════════════════════════╗
║          小瓷连网 XiaoCi Net            ║
║                                          ║
║     Copyright © 2025 [你的名字]         ║
║     Licensed under GNU GPL v3            ║
║                                          ║
║  本软件受《著作权法》保护                ║
║  开源不等于可以随意抄袭和冒充            ║
║                                          ║
║  GitHub: github.com/your-repo            ║
║  作者：[你的名字]                        ║
╚══════════════════════════════════════════╝
"@

    if ($ShowDialog) {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show($copyrightInfo, "关于小瓷连网", "OK", "Information")
    } else {
        Write-Host $copyrightInfo -ForegroundColor Cyan
    }
}

function Add-WaterMark {
    # 在GUI界面底部添加水印
    param($Window)
    
    $watermark = New-Object System.Windows.Controls.TextBlock
    $watermark.Text = "小瓷连网 © 2025 [你的名字] | 开源项目，请保留作者信息"
    $watermark.FontSize = 10
    $watermark.Foreground = "#FF999999"
    $watermark.HorizontalAlignment = "Center"
    $watermark.VerticalAlignment = "Bottom"
    $watermark.Margin = "0,0,0,5"
    
    return $watermark
}

function Check-Integrity {
    # 检查代码是否被篡改（删除作者信息）
    $scriptPath = $MyInvocation.PSCommandPath
    
    if ($scriptPath) {
        $content = Get-Content $scriptPath -Raw
        
        # 检查关键版权信息是否存在
        $hasCopyright = $content -match "Copyright.*\[你的名字\]"
        $hasLicense = $content -match "GPL v3"
        
        if (-not $hasCopyright -or -not $hasLicense) {
            Write-Warning "⚠️ 警告：检测到版权信息被篡改！"
            Write-Warning "根据GPL v3许可证，修改后的代码必须保留原作者信息。"
            Write-Warning "当前行为可能构成侵权。"
            
            # 记录到服务器（可选）
            try {
                $report = @{
                    type = "copyright_violation"
                    timestamp = Get-Date
                    machine_id = (Get-WmiObject Win32_ComputerSystemProduct).UUID
                } | ConvertTo-Json
                
                Invoke-RestMethod `
                    -Uri "https://your-server.com/api/report" `
                    -Method POST `
                    -Body $report `
                    -ContentType "application/json" `
                    -TimeoutSec 2
            } catch {
                # 静默失败
            }
        }
    }
}

# 在程序启动时检查
Check-Integrity

# 导出函数
Export-ModuleMember -Function Show-Copyright, Add-WaterMark






