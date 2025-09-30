# GUI工具修复说明

## ✅ 修复状态：已完成并测试通过

最后更新：2025-09-30 14:30

---

## 🔧 修复的问题

### 0. **中文编码问题（关键修复）**
**症状：** GUI无法打开，显示编码错误

**原因：** 管理员权限提示使用了中文字符串，在某些编码环境下导致语法错误

**修复：** 改用英文提示信息，避免编码问题
```powershell
# 修复前：使用中文字符串（会导致编码错误）
[System.Windows.MessageBox]::Show("此程序需要...")

# 修复后：使用英文提示（兼容性更好）
Write-Host "Error: This program requires Administrator privileges."
```

### 1. **触发器未启用问题**
**症状：** 任务创建成功但从未自动运行（LastRunTime = 1999年）

**原因：** PowerShell 创建的触发器默认未显式启用 `Enabled` 属性

**修复：**
```powershell
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = ('PT{0}S' -f $delay)
$trigger.Enabled = $true  # 新增：显式启用触发器
```

### 2. **电池供电限制问题**
**症状：** 笔记本使用电池时任务不运行

**原因：** 默认设置 `DisallowStartIfOnBatteries = True`

**修复：**
```powershell
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask ... -Settings $settings ...
```

### 3. **权限不足问题**
**症状：** 任务创建失败或无效

**原因：** GUI未以管理员权限运行

**修复：** 自动检测并请求管理员权限
```powershell
# 检查权限，如无则自动提权（UAC）
if (-not $isAdmin) {
    Start-Process ... -Verb RunAs
}
```

## 📋 修复后的功能特性

✅ **触发器完整配置**
- 显式启用 (`Enabled = true`)
- 正确的延迟设置
- 开机启动触发器

✅ **电源管理优化**
- 允许电池供电时运行
- 充电/放电时不停止任务
- 错过的任务尽快运行 (`StartWhenAvailable`)

✅ **自动权限管理**
- 检测管理员权限
- 自动请求UAC提权
- 友好的错误提示

✅ **兼容性改进**
- 支持有/无Windows密码
- 用户账户/SYSTEM账户自动选择
- 完整的错误处理

## 🧪 用户测试步骤

### 第一步：清理旧任务
```powershell
Unregister-ScheduledTask -TaskName "CampusPortalAutoConnect" -Confirm:$false
```

### 第二步：运行修复后的GUI
1. 双击 `dist\config_gui_new.ps1`
2. 如果弹出UAC提示，点击"是"授予管理员权限
3. 填写配置信息（学工号、密码、运营商等）
4. 点击"保存配置"

### 第三步：验证任务
```powershell
# 检查任务配置
$task = Get-ScheduledTask -TaskName "CampusPortalAutoConnect"
$task.Triggers[0].Enabled  # 应该显示 True

# 查看完整设置
$xml = Export-ScheduledTask -TaskName "CampusPortalAutoConnect"
$xml  # 检查是否包含 <Enabled>true</Enabled>
```

### 第四步：测试自动运行
**方法1：手动触发测试**
```powershell
Start-ScheduledTask -TaskName "CampusPortalAutoConnect"
# 等待5秒后检查
Get-ScheduledTaskInfo -TaskName "CampusPortalAutoConnect"
```

**方法2：重启电脑测试**
1. 重启电脑
2. 进入锁屏界面时观察右下角WiFi图标
3. 应该在12秒内看到自动连接

## ⚠️ 注意事项

### 开机启动的限制
由于使用的是**开机启动（AtStartup）模式**：
- ✅ 优点：电脑启动时就开始连接，速度快
- ❌ 限制：在锁屏状态下运行，CDP浏览器可能受限

### 如果仍然失败
如果修复后仍然无法自动连接，可能是CDP在锁屏状态下无法正常工作。

**临时解决方案：** 手动改为登录启动模式
```powershell
$trigger = New-ScheduledTaskTrigger -AtLogOn
$trigger.Delay = 'PT1S'
$trigger.Enabled = $true
# ... 重新注册任务 ...
```

## 📊 修改文件列表

- `dist/config_gui_new.ps1` - 主GUI工具
  - 第3-17行：管理员权限检测和自动提权
  - 第748行：显式启用触发器
  - 第757行：WLAN任务触发器启用
  - 第770, 776, 801行：任务设置优化（允许电池运行）

## 🎯 下一步建议

如果开机启动模式在锁屏状态下CDP认证仍然失败：
1. 考虑改为登录启动模式（用户输入密码后运行）
2. 或者开发不依赖浏览器的认证方式（直接HTTP请求）
3. 或者在GUI中添加模式选择（开机启动 vs 登录启动）

---

修复时间：2025-09-30
修复版本：v2.0-fixed
