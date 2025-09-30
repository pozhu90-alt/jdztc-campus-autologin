# 校园网自动认证工具 - 全面版本

> 基于 CDP (Chrome DevTools Protocol) 的校园网 Portal 自动认证解决方案

## 🌟 项目特点

- **🤖 智能认证**：使用 CDP 协议模拟真实用户操作，自动填写账号密码并登录
- **📡 智能WiFi连接**：自动扫描、选择信号最强的校园网并连接
- **🔐 安全存储**：使用 Windows DPAPI 加密存储密码，日志自动脱敏
- **🚀 开机自启**：登录后自动运行，进入桌面即可上网
- **🎨 图形界面**：提供可视化配置工具，无需手动编辑配置文件
- **📊 智能检测**：自动检测 Portal 劫持，验证网络连通性
- **🔄 保活机制**：认证成功后自动保活，维持网络连接稳定

## 📋 功能列表

### 核心功能
- ✅ WiFi 自动连接（支持多SSID、信号强度优选）
- ✅ Portal 自动认证（CDP 页面自动化）
- ✅ 开机自启动（用户登录触发）
- ✅ 多运营商支持（联通/电信/移动）
- ✅ 网络状态监控和保活
- ✅ 图形化配置界面

### 高级特性
- 🎯 基于SSID的运营商规则匹配
- 📍 信号强度检测和最低阈值过滤
- 🔄 智能重试和网络验证
- 📝 详细的日志记录
- 🛡️ 残留进程清理

## 🔧 工作原理

### 整体流程

```
开机 → Windows自动连接WiFi（配置为自动连接）
  ↓
用户登录 → 触发计划任务
  ↓
扫描校园网 → 检查信号强度 → 连接/确认WiFi
  ↓
启动浏览器（无头模式）→ 打开Portal页面
  ↓
注入JavaScript → 自动填写账号密码 → 点击登录
  ↓
验证网络连通性 → 启动保活任务 → 完成
```

### 技术细节

1. **WiFi连接**
   - 使用 `netsh wlan` 命令扫描和连接
   - 智能选择信号最强的SSID
   - 自动创建开放网络配置文件
   - 记忆上次成功连接的网络

2. **Portal认证**
   - 使用 CDP (Chrome DevTools Protocol) 控制浏览器
   - 通过 WebSocket 连接浏览器调试端口
   - 注入 JavaScript 自动填写表单
   - 模拟真实用户点击行为

3. **安全机制**
   - 使用 Windows DPAPI 加密密码
   - 密码仅当前用户可解密
   - 日志中自动脱敏敏感信息
   - 清理浏览器临时数据

## 📁 目录结构

```
06-全面版本/
├── README.md                          # 项目说明文档
├── config.json                        # 主配置文件
├── secrets.json                       # 加密密码存储（DPAPI）
├── wifi_state.json                    # WiFi连接状态记录
├── campus_network.log                 # 运行日志
│
├── scripts/                           # 核心脚本
│   ├── start_auth.ps1                # 主入口脚本
│   ├── kill_portal_popup.ps1         # 清理Portal弹窗
│   └── modules/                      # 功能模块
│       ├── wifi.psm1                 # WiFi连接和扫描
│       ├── cdp.psm1                  # CDP浏览器控制
│       ├── netdetect.psm1            # 网络检测和保活
│       └── security.psm1             # 密码加密存储
│
├── portal_autofill/                   # 页面自动填充
│   └── autofill_core.js              # Portal表单自动化脚本
│
├── tasks/                             # 任务计划
│   └── install_autostart.ps1         # 安装自启动任务
│
├── dist/                              # 可执行程序和GUI
│   ├── CampusNet.exe                 # 主程序（带配置）
│   ├── CampusNet_blank.exe           # 空白程序（无配置）
│   ├── config_gui_new.ps1            # 图形配置界面（推荐）
│   └── config_gui_admin.ps1          # 管理员配置界面
│
└── build/                             # 构建工具
    ├── make_ps2exe_obf.ps1           # 编译为EXE
    ├── make_iexpress.ps1             # 打包为安装包
    └── launcher.ps1                  # 启动器脚本
```

## 🚀 快速开始

### 方法一：使用图形界面（推荐）

1. **运行配置工具**
   ```powershell
   # 以管理员身份运行 PowerShell
   cd dist
   .\config_gui_new.ps1
   ```

2. **填写配置信息**
   - 学号（Portal账号）
   - 密码（自动加密存储）
   - Windows密码（用于任务计划，可选）
   - 选择运营商（联通/电信/移动）
   - 选择WiFi网络（自动扫描）

3. **安装自启动**
   - 在GUI中点击"安装自启动任务"
   - 或者勾选"启用开机自启动"

4. **测试运行**
   - 点击"立即测试连接"按钮
   - 查看日志输出

### 方法二：手动配置

1. **编辑配置文件**
   
   编辑 `config.json`：
   ```json
   {
       "username": "你的学号",
       "credential_id": "CampusPortalCredential",
       "wifi_names": ["JCI", "JCU"],
       "portal_entry_url": "http://172.29.0.2/a79.htm",
       "portal_probe_url": "http://www.gstatic.com/generate_204",
       "isp": "unicom",
       "browser": "edge",
       "headless": true,
       "min_signal_percent": 40
   }
   ```

2. **保存密码（加密存储）**
   ```powershell
   Import-Module .\scripts\modules\security.psm1
   Save-Secret -Id "CampusPortalCredential" -Secret (Read-Host -AsSecureString "输入Portal密码")
   ```

3. **测试运行**
   ```powershell
   .\scripts\start_auth.ps1
   ```
   查看 `campus_network.log` 确认运行状态

4. **安装自启动**
   ```powershell
   # 登录启动（推荐）
   .\tasks\install_autostart.ps1 -Mode logon
   
   # 开机启动（需要Windows密码）
   .\tasks\install_autostart.ps1 -Mode startup -DelaySec 8
   ```

## ⚙️ 配置说明

### config.json 字段说明

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `username` | String | Portal登录账号 | `"231080906218"` |
| `credential_id` | String | 密码存储ID | `"CampusPortalCredential"` |
| `wifi_names` | Array | WiFi SSID列表 | `["JCI", "JCU"]` |
| `portal_entry_url` | String | Portal入口地址 | `"http://172.29.0.2/a79.htm"` |
| `portal_probe_url` | String | 劫持检测URL | `"http://www.gstatic.com/generate_204"` |
| `isp` | String | 运营商 | `"unicom"` / `"telecom"` / `"cmcc"` |
| `browser` | String | 浏览器类型 | `"edge"` / `"chrome"` |
| `headless` | Boolean | 无头模式 | `true` / `false` |
| `min_signal_percent` | Number | 最低信号强度（%） | `40` |
| `autostart_enabled` | Boolean | 是否启用自启动 | `true` / `false` |

### SSID规则匹配

支持按SSID自动切换运营商：

```json
"ssid_rules": [
    {
        "pattern": "JCI",
        "isp": "unicom"
    },
    {
        "pattern": "JCU*",
        "isp": ""
    }
]
```

- 精确匹配：`"JCI"`
- 通配符：`"JCU*"` 或 `"SXL*"`
- 正则表达式：`"^JCI\d+"` （以^开头）

## 🔍 故障排查

### 问题1：WiFi连接但无Internet

**症状**：进入桌面看到WiFi已连接，但无法上网

**原因**：登录后程序立即启动，但DHCP还未获取到IP地址

**解决方案**：

1. **修改任务计划延迟**（推荐）
   ```powershell
   .\tasks\install_autostart.ps1 -Mode logon -DelaySec 5
   ```

2. **修改配置文件**
   在 `config.json` 中调整：
   ```json
   {
       "autostart_delay_sec": 3,
       "boot_extra_delay_ms": 2000
   }
   ```

3. **检查网络获取情况**
   ```powershell
   ipconfig /all
   netsh wlan show interfaces
   ```

### 问题2：CDP认证失败

**症状**：日志显示 "CDP executed but returned false"

**可能原因**：
1. 浏览器未找到或版本不兼容
2. Portal页面结构变化
3. 网络未就绪

**解决方案**：
1. 确认Edge或Chrome已安装
2. 查看日志中的详细错误信息
3. 手动测试：
   ```powershell
   .\scripts\start_auth.ps1
   # 查看 campus_network.log
   ```

### 问题3：无法获取WiFi信息

**症状**：日志显示 "Cannot get valid WiFi info"

**解决方案**：
1. 检查WLAN服务状态：
   ```powershell
   Get-Service WlanSvc
   Set-Service WlanSvc -StartupType Automatic
   Start-Service WlanSvc
   ```

2. 手动启用WiFi适配器：
   ```powershell
   Get-NetAdapter | Where-Object {$_.Name -match "Wi-Fi"}
   Enable-NetAdapter -Name "Wi-Fi"
   ```

### 问题4：浏览器进程残留

**症状**：多个msedge/chrome进程未关闭

**解决方案**：
```powershell
# 清理残留进程
.\scripts\kill_portal_popup.ps1

# 或手动清理
Get-Process msedge,chrome -ErrorAction SilentlyContinue | Stop-Process -Force
```

## 🔧 高级功能

### 登录 vs 开机启动

程序支持两种启动模式：

| 模式 | 触发时机 | 需要密码 | 适用场景 |
|------|---------|---------|---------|
| **登录启动** | 用户登录后 | ❌ 不需要 | 个人电脑（推荐） |
| **开机启动** | 系统启动时 | ✅ 需要 | 无人值守服务器 |

**当前配置**：默认使用**登录启动**

**工作机制**：
1. 开机时 → Windows自动连接WiFi（因为JCI配置为自动连接）
2. 用户登录 → 触发程序运行
3. 程序启动 → 等待网络就绪 → Portal认证

### 手动切换启动模式

```powershell
# 切换为登录启动
.\tasks\install_autostart.ps1 -Mode logon

# 切换为开机启动（需要输入Windows密码）
.\tasks\install_autostart.ps1 -Mode startup -DelaySec 8
```

### 网络保活机制

认证成功后，程序会启动后台保活任务：
- 间隔：10秒
- 持续：3分钟
- 方法：定期访问外网验证连通性

### 信号强度过滤

可设置最低信号强度，避免连接到信号弱的AP：

```json
{
    "min_signal_percent": 40
}
```

程序会跳过信号低于40%的WiFi。

## 📝 日志说明

### 日志位置
- 默认：`campus_network.log`
- 自定义：在 `config.json` 中修改 `log_file` 字段

### 日志级别
- `[INFO]`：正常信息
- `[WARN]`：警告信息
- `[ERROR]`：错误信息
- `[SUCCESS]`：成功信息

### 日志示例

```
[2025-09-30 16:14:24] [INFO] ✅ WiFi module loaded
[2025-09-30 16:14:24] [INFO] 检测到校园网 'JCI'，信号强度=89%（阈值=40%）
[2025-09-30 16:14:24] [INFO] Start auth pipeline
[2025-09-30 16:14:25] [INFO] WiFi connected successfully
[2025-09-30 16:14:28] [INFO] Network: IPv4=10.111.22.33, MAC=XX:XX:XX:XX:XX:XX
[2025-09-30 16:14:29] [INFO] ISP: unicom -> 中国联通
[2025-09-30 16:14:31] [INFO] ✅ CDP executed successfully
[2025-09-30 16:14:32] [SUCCESS] ✅ 认证完成，已启动后台保活
```

## 🛠️ 开发和构建

### 编译为EXE

```powershell
cd build
.\make_ps2exe_obf.ps1
```

生成的文件在 `dist/` 目录。

### 打包为安装程序

```powershell
cd build
.\make_iexpress.ps1
```

### 语法检查

```powershell
cd build
.\check_ps_syntax.ps1
```

## ⚠️ 注意事项

1. **系统要求**
   - Windows 10/11
   - PowerShell 5.1 或更高
   - Edge 或 Chrome 浏览器

2. **权限要求**
   - 安装自启动需要管理员权限
   - WiFi连接需要WLAN服务运行
   - 修改网络配置需要相应权限

3. **安全建议**
   - 不要分享 `secrets.json` 文件
   - 不要上传包含真实密码的配置
   - 定期更换Portal密码

4. **杀毒软件**
   - 部分杀毒软件可能误报
   - 建议将程序目录加入白名单
   - 无头浏览器可能被拦截

## 📚 相关文档

- [GUI修复说明.md](GUI修复说明.md) - GUI问题修复记录
- [GUI最终版本说明-v4.0.txt](GUI最终版本说明-v4.0.txt) - GUI v4.0更新说明
- [快速启动问题解决方案.md](快速启动问题解决方案.md) - 启动问题排查指南

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可

本项目仅供学习交流使用，请遵守学校网络使用规定。

## 🔗 技术栈

- PowerShell 5.1+
- Chrome DevTools Protocol (CDP)
- Windows DPAPI
- Windows Task Scheduler
- WPF (Windows Presentation Foundation)

---

**最后更新时间**：2025-09-30