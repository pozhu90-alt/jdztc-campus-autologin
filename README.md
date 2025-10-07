# 小瓷连网 - 校园网自动认证工具

<div align="center">

![Version](https://img.shields.io/badge/version-1.0.1-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey.svg)

一款优雅、智能的校园网自动认证工具，专为景德镇陶瓷大学等使用深澜校园网的高校设计。

</div>

---

## 🆕 更新日志

### v1.0.1 (2025-10-06)
- 🔧 **修复**：GUI界面中QQ群和打赏二维码图片不显示的问题
  - 原因：`make_ps2exe_obf.ps1`中嵌入路径使用了双反斜杠导致路径错误
  - 解决：统一使用单反斜杠路径分隔符
- 🧹 **优化**：清理build文件夹无用文件
  - 删除：`make_iexpress.ps1`（已废弃的IExpress打包方式）
  - 删除：`make_blank.ps1`（功能已被`-Blank`参数替代）
  - 删除：`convert_icon.ps1` 和 `make_icon.ps1`（重复的图标转换工具）
  - 删除：`make_xiaoci.ps1`（包装脚本，已简化）
- ✨ **改进**：简化编译流程，一条命令即可完成编译
- 📝 **文档**：更新README，添加最新修复说明和云函数状态

### v1.0.0 (2025-10-03)
- 🎉 **首个正式发布版本**
- 🎨 精美的小瓷风格GUI界面
- 🚀 自动连接校园网（深澜认证）
- 📊 匿名使用统计系统（Supabase数据库）
- 🔄 在线版本更新机制
- 🔒 密码加密存储（DPAPI）

---

## 📖 目录

- [核心功能](#-核心功能)
- [快速开始](#-快速开始)
- [系统架构](#-系统架构)
- [开发指南](#-开发指南)
  - [环境要求](#环境要求)
  - [项目结构](#项目结构)
  - [编译程序](#编译程序)
- [云函数部署](#-云函数部署)
  - [部署到腾讯云](#1-部署到腾讯云)
  - [配置Supabase数据库](#2-配置supabase数据库)
  - [更新云函数代码](#3-更新云函数代码)
- [用户统计系统](#-用户统计系统)
  - [统计原理](#统计原理)
  - [查看统计数据](#查看统计数据)
  - [数据说明](#数据说明)
- [版本更新机制](#-版本更新机制)
  - [发布新版本](#发布新版本)
  - [用户更新流程](#用户更新流程)
- [隐私政策](#-隐私政策)
- [常见问题](#-常见问题)
- [许可证](#-许可证)

---

## ✨ 核心功能

### 🌐 智能网络认证
- **自动WiFi连接**：智能扫描并连接校园网（支持正则、通配符、精确匹配）
- **深澜认证支持**：使用CDP（Chrome DevTools Protocol）自动化认证
- **门户网页检测**：自动识别并处理认证页面
- **网络保活**：认证成功后自动保活（10秒/次，持续3分钟）
- **断线重连**：网络异常时自动重试

### 🎨 现代化GUI界面
- **陶瓷主题设计**：渐变背景、圆角按钮、优雅配色
- **实时状态显示**：连接状态、信号强度、运营商信息
- **无边框窗口**：自定义标题栏，支持拖拽、最小化、关闭
- **自适应布局**：DPI感知，支持高分辨率显示器

### 📊 用户统计系统
- **匿名数据收集**：只收集设备ID（加密）、版本号、启动时间、操作系统
- **实时统计面板**：Web界面展示用户数、DAU/WAU/MAU、启动次数
- **数据永久存储**：使用Supabase PostgreSQL数据库
- **完全免费**：基于腾讯云函数 + Supabase免费套餐

### 🔄 自动版本更新
- **后台版本检查**：程序启动时自动检查新版本
- **友好更新提示**：弹窗显示更新日志和文件大小
- **一键下载更新**：自动下载并替换旧版本
- **无感更新**：后台进行，不影响当前使用

### 🔒 安全与隐私
- **密码加密存储**：使用DPAPI（Windows数据保护API）
- **匿名统计**：设备ID经SHA256哈希，无法反推身份
- **透明公开**：GUI界面明确说明数据收集内容
- **开源可审计**：代码完全开源，接受社区审查

### 🚀 其他特性
- **开机自启**：可选配置为开机自动运行
- **静默运行**：可配置为后台静默认证
- **多运营商支持**：自动识别联通/电信/移动
- **详细日志**：记录认证过程，便于排查问题

---

## 🚀 快速开始

### 用户使用

#### 方式一：使用预配置版（推荐）
1. 下载 `小瓷连网.exe`（已内置景德镇陶瓷大学配置）
2. 双击运行
3. 输入校园网账号和密码
4. 点击"保存并连接"
5. 等待5-10秒，自动完成认证

#### 方式二：使用空白版
1. 下载 `小瓷连网_空白版.exe`
2. 运行后填写完整配置：
   - WiFi名称（如：`JCI`）
   - 认证地址（深澜ePortal地址）
   - 账号密码
   - 运营商（联通/电信/移动）
3. 保存并连接

### 系统要求
- Windows 10/11 (x64)
- PowerShell 5.1+
- .NET Framework 4.8+

---

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                     小瓷连网.exe                             │
│  (PowerShell + WPF GUI + ps2exe编译)                        │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    │ 认证成功后发送统计
                    ↓
┌─────────────────────────────────────────────────────────────┐
│            腾讯云函数 (Serverless API)                       │
│  - 接收统计数据 (POST /stats)                               │
│  - 返回版本信息 (GET /version)                              │
│  - 提供仪表盘数据 (GET /dashboard)                          │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    │ 读写数据
                    ↓
┌─────────────────────────────────────────────────────────────┐
│              Supabase PostgreSQL 数据库                      │
│  - users 表: 存储用户设备信息                               │
│  - launches 表: 存储每次启动记录                            │
└─────────────────────────────────────────────────────────────┘
                    ↑
                    │ 获取统计数据
                    │
┌─────────────────────────────────────────────────────────────┐
│         stats_dashboard.html (统计面板)                      │
│  - 实时显示用户数、DAU/WAU/MAU                              │
│  - 图表可视化                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ 开发指南

### 环境要求

```powershell
# 1. PowerShell 5.1+ (Windows 10自带)
$PSVersionTable.PSVersion

# 2. ps2exe模块 (用于编译PowerShell到EXE)
Install-Module -Name ps2exe -Scope CurrentUser

# 3. Git (可选，用于版本管理)
winget install Git.Git
```

### 项目结构

```
06-全面版本/
├── build/                          # 编译脚本（已精简✨）
│   ├── launcher.ps1                # 主启动脚本
│   ├── launcher_debug.ps1          # 调试启动脚本
│   ├── make_ps2exe_obf.ps1         # 主编译脚本（核心）
│   ├── config.blank.json           # 空白版配置
│   ├── ps2exe.ps1                  # ps2exe核心
│   ├── check_ps_syntax.ps1         # 语法检查工具
│   ├── print_cfg.ps1               # 配置打印工具
│   ├── test_simple.ps1             # 简单测试脚本
│   └── test_launcher.ps1           # 启动器测试脚本
├── scripts/                        # 核心逻辑
│   ├── start_auth.ps1              # 认证主流程
│   └── modules/                    # 功能模块
│       ├── wifi.psm1               # WiFi连接
│       ├── netdetect.psm1          # 网络检测
│       ├── security.psm1           # 密码加密
│       ├── cdp.psm1                # CDP自动化
│       ├── stats.psm1              # 统计模块 (新增)
│       └── updater.psm1            # 更新模块 (新增)
├── dist/                           # 分发文件
│   ├── 小瓷连网.exe                # 正常版可执行文件
│   ├── 小瓷连网_空白版.exe         # 空白版可执行文件
│   ├── config_gui_xiaoci.ps1       # GUI界面代码
│   ├── stats_dashboard.html        # 统计面板 (新增)
│   ├── xiaoci_cloud_function_supabase_v2.js  # 云函数代码 (新增)
│   └── *.png                       # 图标资源
├── gui/                            # GUI源码
│   └── home.ps1                    # GUI主文件
├── portal_autofill/                # 认证脚本
│   └── autofill_core.js            # CDP自动化脚本
├── config.json                     # 主配置文件
├── schools_config.json             # 学校配置库
└── README.md                       # 本文档
```

### 编译程序

#### 快速编译（推荐）
```powershell
# 在项目根目录执行

# 编译正常版（包含所有资源和图片）
powershell -ExecutionPolicy Bypass -File "build\make_ps2exe_obf.ps1" -OutputName "小瓷连网.exe"

# 编译空白版（不含学校配置）
powershell -ExecutionPolicy Bypass -File "build\make_ps2exe_obf.ps1" -OutputName "小瓷连网_空白版.exe" -Blank

# 编译调试版（显示详细错误信息）
powershell -ExecutionPolicy Bypass -File "build\make_ps2exe_obf.ps1" -OutputName "小瓷连网_debug.exe" -Debug
```

#### 编译说明
- ✅ 所有图片资源（QQ群、打赏二维码等）会自动嵌入到exe中
- ✅ 配置文件、脚本、模块全部打包到exe中
- ✅ 单文件运行，无需额外依赖
- ✅ 编译完成后，可执行文件在 `dist/` 目录

#### 最新修复（2025-10-06）
- 🔧 修复了GUI界面中QQ群和打赏图片不显示的问题
- 🧹 清理了build文件夹中的无用文件（删除了5个旧脚本）
- ✨ 简化了编译流程，一条命令即可完成编译

---

## ☁️ 云函数部署

> **✅ 当前状态**：云函数已部署并正常运行
> - 云函数地址：`https://1381467633-52ewvuipwd.ap-guangzhou.tencentscf.com`
> - 版本API：✅ 正常
> - 统计API：✅ 正常
> - 数据库：✅ Supabase连接正常

### 1. 部署到腾讯云

#### 步骤1：创建云函数

1. 打开 [腾讯云函数控制台](https://console.cloud.tencent.com/scf/list?rid=1&ns=default)
2. 点击 **新建** → **从头开始**
3. 填写基本信息：
   - **函数名称**: `xiaoci_stats`（或其他名称）
   - **运行环境**: `Node.js 16.13`
   - **创建方式**: 空白函数

#### 步骤2：配置函数代码

1. 在 **函数代码** 标签页：
   - 删除默认代码
   - 复制 `dist/xiaoci_cloud_function_supabase_v2.js` 的全部内容
   - 粘贴到代码编辑器

2. 修改代码中的配置：
   ```javascript
   // 修改第5-6行，填入你的Supabase信息
   const SUPABASE_URL = 'https://你的项目.supabase.co';
   const SUPABASE_KEY = '你的anon public key';
   
   // 修改第9-13行，配置版本信息
   const VERSION_CONFIG = {
       latestVersion: '1.0.0',           // 当前最新版本
       downloadUrl: 'http://your-url',   // 下载地址
       updateLog: '1. 首次发布\n2. ...',  // 更新日志
       downloadSize: '5.66 MB'           // 文件大小
   };
   ```

3. 点击 **部署**

#### 步骤3：启用公网访问

1. 切换到 **触发管理** 标签页
2. 点击 **创建触发器**
3. 选择 **自定义创建**：
   - **触发方式**: API网关触发（如果没有，选择"新建API网关触发器"）
   - **开启集成响应**: 勾选
4. 点击 **提交**
5. 复制生成的 **访问路径**（形如：`https://xxx-xxx.ap-guangzhou.tencentscf.com`）

#### 步骤4：配置CORS（跨域）

1. 在代码编辑器中，确保响应头包含CORS设置：
   ```javascript
   const headers = {
       'Content-Type': 'application/json',
       'Access-Control-Allow-Origin': '*',  // 允许所有域名访问
       'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
       'Access-Control-Allow-Headers': 'Content-Type'
   };
   ```
   （代码中已包含，无需修改）

2. 重新 **部署**

#### 步骤5：更新客户端配置

1. 修改 `scripts/modules/stats.psm1` 第4行：
   ```powershell
   $script:StatsApiUrl = "https://你的云函数地址"
   ```

2. 修改 `scripts/modules/updater.psm1` 第10行：
   ```powershell
   $cloudFunctionBaseUrl = "https://你的云函数地址"
   ```

3. 修改 `dist/stats_dashboard.html` 第169行：
   ```javascript
   const CLOUD_FUNCTION_BASE_URL = "https://你的云函数地址";
   ```

4. 重新编译程序：
   ```powershell
   cd build
   .\make_xiaoci.ps1
   ```

---

### 2. 配置Supabase数据库

> **✅ 当前状态**：数据库已配置并正常运行
> - 总用户数：1
> - 总启动次数：27
> - 实时统计：正常工作中

#### 步骤1：创建Supabase项目

1. 访问 [Supabase](https://supabase.com/)
2. 注册/登录账号（支持GitHub登录）
3. 点击 **New Project**
4. 填写项目信息：
   - **Name**: `xiaoci-stats`（或其他名称）
   - **Database Password**: 设置一个强密码（请记住！）
   - **Region**: 选择 `Southeast Asia (Singapore)`（国内访问较快）
5. 点击 **Create new project**（等待2-3分钟初始化）

#### 步骤2：创建数据表

1. 进入项目后，点击左侧 **Table Editor**
2. 点击 **Create a new table**

**创建 users 表：**
```sql
-- Table: users (用户设备信息)
CREATE TABLE users (
    id TEXT PRIMARY KEY,              -- 设备ID（主键）
    version TEXT,                     -- 程序版本
    os TEXT,                          -- 操作系统
    first_seen TIMESTAMPTZ DEFAULT NOW(),  -- 首次使用时间
    last_seen TIMESTAMPTZ DEFAULT NOW()    -- 最后使用时间
);
```

配置方式：
- **Name**: `users`
- **Columns**:
  - `id` - Type: `text` - Primary Key: ✅ - Default value: -
  - `version` - Type: `text` - Default value: -
  - `os` - Type: `text` - Default value: -
  - `first_seen` - Type: `timestamptz` - Default value: `now()`
  - `last_seen` - Type: `timestamptz` - Default value: `now()`
- **Enable RLS (Row Level Security)**: ❌ **取消勾选**（重要！）

**创建 launches 表：**
```sql
-- Table: launches (启动记录)
CREATE TABLE launches (
    id SERIAL PRIMARY KEY,            -- 自动递增ID（主键）
    user_id TEXT NOT NULL,            -- 设备ID（外键）
    launched_at TIMESTAMPTZ DEFAULT NOW()  -- 启动时间
);
```

配置方式：
- **Name**: `launches`
- **Columns**:
  - `id` - Type: `int8` - Primary Key: ✅ - Default value: - **Identity Generation**: ✅ **勾选**
  - `user_id` - Type: `text` - Default value: -
  - `launched_at` - Type: `timestamptz` - Default value: `now()`
- **Enable RLS (Row Level Security)**: ❌ **取消勾选**（重要！）

#### 步骤3：获取API密钥

1. 点击左侧 **Project Settings** (齿轮图标)
2. 点击 **API**
3. 复制以下信息：
   - **Project URL**: `https://你的项目.supabase.co`
   - **anon public key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`（很长的字符串）

#### 步骤4：测试数据库连接

```powershell
# 在PowerShell中测试
$headers = @{
    'apikey' = '你的anon public key'
    'Authorization' = 'Bearer 你的anon public key'
}

# 测试查询users表
Invoke-RestMethod -Uri 'https://你的项目.supabase.co/rest/v1/users' -Headers $headers

# 如果返回空数组 [] 表示连接成功
```

---

### 3. 更新云函数代码

如果需要修改云函数逻辑（如版本号、统计规则等）：

1. 本地编辑 `dist/xiaoci_cloud_function_supabase_v2.js`
2. 登录 [腾讯云函数控制台](https://console.cloud.tencent.com/scf/list)
3. 找到你的函数（如 `xiaoci_stats`）
4. 点击 **函数代码**
5. 全选删除旧代码（Ctrl+A, Delete）
6. 粘贴新代码（Ctrl+V）
7. 点击 **部署**
8. 等待部署完成（约10秒）

---

## 📊 用户统计系统

### 统计原理

#### 数据收集流程

```
用户运行程序
  ↓
连接校园网成功
  ↓
生成设备ID（SHA256哈希）
  ↓
发送统计数据到云函数
  ↓
云函数存储到Supabase
  ↓
统计面板展示数据
```

#### 收集的数据（仅4项）

| 字段 | 说明 | 示例 | 隐私等级 |
|------|------|------|---------|
| `id` | 设备ID（SHA256哈希） | `aB3dF5gH7jK9lM2n` | ✅ 完全匿名 |
| `v` | 程序版本号 | `1.0.0` | ✅ 无隐私风险 |
| `t` | 启动时间戳 | `1696464000` | ✅ 无隐私风险 |
| `os` | 操作系统版本 | `Microsoft Windows NT 10.0` | ✅ 无隐私风险 |

**不收集的信息**：
- ❌ 姓名、学号、工号
- ❌ IP地址、MAC地址
- ❌ 账号密码
- ❌ 学校名称、地理位置
- ❌ WiFi密码
- ❌ 浏览记录、文件内容

### 查看统计数据

#### 方式1：使用统计面板（推荐）

1. 双击打开 `dist/stats_dashboard.html`
2. 浏览器自动显示：
   - 📊 总用户数
   - 👤 今日/本周/本月活跃用户（DAU/WAU/MAU）
   - 🚀 总启动次数
   - 📈 数据图表

3. 面板每5秒自动刷新数据

#### 方式2：直接查询云函数API

```powershell
# 查询统计数据
Invoke-RestMethod -Uri "https://你的云函数地址/dashboard"

# 返回示例：
# {
#   "totalUsers": 156,
#   "dau": 45,
#   "wau": 98,
#   "mau": 132,
#   "totalLaunches": 1247
# }
```

#### 方式3：在Supabase后台查看

1. 登录 [Supabase控制台](https://supabase.com/dashboard)
2. 进入你的项目
3. 点击 **Table Editor**
4. 查看 `users` 表和 `launches` 表

### 数据说明

| 指标 | 英文缩写 | 计算方式 | 业务意义 |
|------|---------|---------|---------|
| 总用户数 | Total Users | `users` 表总行数 | 有多少台电脑安装了程序 |
| 日活跃用户 | DAU | 今天启动过的设备数 | 今天有多少人在用 |
| 周活跃用户 | WAU | 最近7天启动过的设备数 | 一周有多少活跃用户 |
| 月活跃用户 | MAU | 最近30天启动过的设备数 | 一个月有多少活跃用户 |
| 总启动次数 | Total Launches | `launches` 表总行数 | 程序一共被启动了多少次 |

**示例分析**：
- 如果 `总用户数=500, DAU=150`，说明有500人安装了程序，今天有150人在用（活跃率30%）
- 如果 `总启动次数=2000, 总用户数=500`，说明平均每个用户启动了4次

---

## 🔄 版本更新机制

### 发布新版本

#### 步骤1：编译新版本

```powershell
# 1. 修改版本号
# 编辑 scripts/modules/stats.psm1 第5行
$script:CurrentVersion = "1.1.0"  # 改为新版本号

# 2. 编译新版本
cd build
.\make_xiaoci.ps1

# 3. 测试新版本
cd ..\dist
.\小瓷连网.exe
```

#### 步骤2：上传文件到网盘

推荐使用以下方式：

**方式1：蓝奏云（推荐）**
- 优点：免费、不限速、稳定
- 缺点：单文件限制100MB
- 地址：https://www.lanzou.com/

**方式2：GitHub Releases**
```powershell
# 1. 创建Git标签
git tag -a v1.1.0 -m "版本 1.1.0 发布"
git push origin v1.1.0

# 2. 在GitHub上创建Release
# - 访问你的仓库
# - 点击 Releases → Create a new release
# - 选择标签 v1.1.0
# - 上传 小瓷连网.exe
# - 填写更新说明
# - 点击 Publish release

# 3. 获取下载地址（右键复制链接）
# https://github.com/你的用户名/仓库名/releases/download/v1.1.0/小瓷连网.exe
```

**方式3：阿里云盘 / 百度网盘**
- 生成分享链接（需要公开访问）

#### 步骤3：更新云函数配置

1. 打开 [腾讯云函数控制台](https://console.cloud.tencent.com/scf/list)
2. 找到你的函数，点击 **函数代码**
3. 修改版本配置（第9-13行）：
   ```javascript
   const VERSION_CONFIG = {
       latestVersion: '1.1.0',  // 改为新版本号
       downloadUrl: 'https://你的下载地址/小瓷连网.exe',  // 改为新下载地址
       updateLog: '更新内容：\n1. 修复了XXX问题\n2. 新增了XXX功能\n3. 优化了XXX性能',
       downloadSize: '5.72 MB'  // 改为新文件大小
   };
   ```
4. 点击 **部署**

#### 步骤4：测试更新

```powershell
# 运行旧版本程序，查看是否弹出更新提示
.\小瓷连网_旧版.exe

# 应该看到更新弹窗：
# "发现新版本 1.1.0！（当前版本: 1.0.0）
#  更新内容：...
#  文件大小：5.72 MB
#  是否立即下载更新？"
```

### 用户更新流程

用户端完全自动化，无需手动操作：

1. **启动程序** → 后台检查更新（3秒后）
2. **发现新版本** → 弹窗提示
3. **点击"是"** → 自动下载到临时目录
4. **下载完成** → 提示"即将关闭程序"
5. **自动替换** → 旧版本被新版本覆盖
6. **自动启动** → 新版本自动运行
7. **完成** → 用户无感知更新

**如果用户点击"否"**：
- 跳过本次更新
- 下次启动仍会提示

**更新失败处理**：
- 网络异常：静默跳过，不影响程序使用
- 下载失败：提示用户手动下载
- 替换失败：保留旧版本，不影响使用

---

## 🔒 隐私政策

### 数据收集声明

本程序在用户连接校园网成功后，会收集以下**匿名统计数据**：

| 数据项 | 内容 | 用途 | 隐私风险 |
|--------|------|------|---------|
| 设备ID | 硬件信息SHA256哈希 | 统计去重（避免重复计数） | ✅ 无风险（无法反推身份） |
| 版本号 | 如 `1.0.0` | 统计版本分布 | ✅ 无风险 |
| 启动时间 | Unix时间戳 | 计算活跃度（DAU/WAU/MAU） | ✅ 无风险 |
| 操作系统 | 如 `Windows 10` | 优化兼容性 | ✅ 无风险 |

### 不收集的信息

- ❌ **个人身份信息**：姓名、学号、工号、身份证号
- ❌ **账号密码**：校园网账号密码（仅本地加密存储）
- ❌ **网络信息**：IP地址、MAC地址、WiFi密码
- ❌ **位置信息**：学校名称、地理位置、GPS坐标
- ❌ **使用行为**：浏览记录、应用列表、文件内容

### 数据安全措施

1. **加密传输**：使用HTTPS加密传输数据
2. **匿名化处理**：设备ID经SHA256单向哈希，无法反推
3. **最小化收集**：只收集必要的统计数据
4. **透明公开**：GUI界面"关于"按钮中明确说明
5. **用户知情**：用户首次使用时可查看隐私说明
6. **数据用途**：仅用于统计分析，不用于商业目的
7. **数据保留**：永久保存统计数据（用于长期分析）

### 如何关闭统计

如果你想完全关闭统计功能：

```powershell
# 1. 编辑 scripts/start_auth.ps1
# 2. 注释掉第311-342行（统计和更新模块）
# 3. 重新编译程序

# 或者直接删除统计模块
Remove-Item scripts\modules\stats.psm1
Remove-Item scripts\modules\updater.psm1
```

### 合规性说明

本项目遵守以下隐私法规：
- ✅ **GDPR（欧盟通用数据保护条例）**：数据匿名化、用户知情
- ✅ **中国《个人信息保护法》**：最小化收集、透明公开
- ✅ **中国《网络安全法》**：数据加密传输、安全存储

---

## 🔍 云函数和数据库健康检查

### 快速检查命令

在PowerShell中运行以下命令：

```powershell
# 1. 检查云函数状态
Invoke-RestMethod -Uri "https://1381467633-52ewvuipwd.ap-guangzhou.tencentscf.com/" -UseBasicParsing

# 2. 检查版本API
Invoke-RestMethod -Uri "https://1381467633-52ewvuipwd.ap-guangzhou.tencentscf.com/version" -UseBasicParsing | ConvertTo-Json

# 3. 检查统计数据（验证数据库连接）
Invoke-RestMethod -Uri "https://1381467633-52ewvuipwd.ap-guangzhou.tencentscf.com/dashboard" -UseBasicParsing | ConvertTo-Json
```

### 预期结果

✅ **正常状态**：
```json
// 云函数根路径
"小瓷连网云服务运行中（Supabase免费版 v2）✓"

// 版本API
{
  "latestVersion": "1.0.0",
  "downloadUrl": "...",
  "updateLog": "..."
}

// 统计数据
{
  "totalUsers": 1,
  "totalLaunches": 27,
  "dau": 1,
  "wau": 1,
  "mau": 1
}
```

---

## ❓ 常见问题

### 编译相关

**Q: 提示"无法加载文件 ps2exe.ps1"？**

A: 执行策略问题，运行：
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

**Q: 编译后图标不显示？**

A: 检查 `dist/xi2o7-p1m0u-001.ico` 是否存在，重新运行：
```powershell
cd build
.\make_xiaoci.ps1
```

**Q: 编译出错："另一个程序正在使用此文件"？**

A: 关闭正在运行的exe程序，然后重新编译。

**Q: GUI界面不显示QQ群和打赏图片？**

A: 这个问题在v1.0.1版本已修复。如果仍然遇到：
1. 确认使用的是最新的`make_ps2exe_obf.ps1`
2. 检查`dist`目录下是否存在以下文件：
   - `donation_qrcode.png`
   - `qq_group_qrcode.png`
3. 重新编译程序：
   ```powershell
   powershell -ExecutionPolicy Bypass -File "build\make_ps2exe_obf.ps1" -OutputName "小瓷连网.exe"
   ```

---

### 云函数相关

**Q: 云函数返回500错误？**

A: 检查以下几点：
1. Supabase的RLS是否已关闭（重要！）
2. `SUPABASE_URL` 和 `SUPABASE_KEY` 是否正确
3. 数据表 `users` 和 `launches` 是否已创建
4. 云函数是否已部署
5. 查看腾讯云函数日志，找到具体错误信息

**详细诊断步骤**：
```powershell
# 测试Supabase连接
$headers = @{
    'apikey' = '你的SUPABASE_KEY'
    'Authorization' = 'Bearer 你的SUPABASE_KEY'
}
Invoke-RestMethod -Uri 'https://你的项目.supabase.co/rest/v1/users' -Headers $headers

# 如果返回 [] 说明连接正常
# 如果返回403错误，说明RLS没关闭
# 如果返回404错误，说明表不存在
```

**Q: 统计面板显示全是0？**

A: 可能原因：
1. CORS配置问题：检查云函数代码中的 `Access-Control-Allow-Origin`
2. 网络问题：打开浏览器F12，查看Console是否有错误
3. 数据库没数据：运行一次程序连网，再刷新面板

**Q: 云函数触发次数过多怎么办？**

A: 腾讯云函数免费额度：每月100万次调用
- 如果超限：升级到付费套餐（按量计费，很便宜）
- 或迁移到其他平台：Cloudflare Workers、Vercel等

---

### 程序使用相关

**Q: 提示"网络验证超时"但能上网？**

A: 正常现象，程序的网络检测比较严格，只要能上网就说明认证成功。

**Q: 程序启动后没反应？**

A: 检查：
1. 是否在校园网覆盖范围内
2. 查看日志文件 `campus_network.log`
3. 使用调试版：`.\make_ps2exe_obf.ps1 -Debug`

**Q: 如何设置开机自启？**

A: 运行程序后，在GUI界面勾选"开机自启"选项。

**Q: 密码保存在哪里？**

A: 使用Windows DPAPI加密存储在：
```
%APPDATA%\CampusNet\secrets.json
```
只有你的Windows账户能解密，安全性高。

---

### 统计相关

**Q: 为什么我运行了多次，但统计只显示1个用户？**

A: 正常现象，同一台电脑的设备ID相同，会被去重。只有不同的电脑才会增加用户数。

**Q: 总启动次数会增加吗？**

A: 会！每次运行程序都会在 `launches` 表新增一条记录，启动次数会累加。

**Q: 如何清空统计数据？**

A: 在Supabase控制台：
```sql
-- 清空users表
DELETE FROM users;

-- 清空launches表
DELETE FROM launches;
```

---

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源协议。

```
MIT License

Copyright (c) 2025 小瓷连网

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🤝 贡献

欢迎提交Issue和Pull Request！

如果这个项目对你有帮助，请给一个⭐Star⭐！

---

## 📧 联系方式

- **项目地址**: [GitHub仓库链接]
- **问题反馈**: [GitHub Issues]
- **技术交流**: [QQ群/微信群/Discord]

---

<div align="center">

**用心打造，用爱连网** ❤️

Made with ❤️ by 小瓷连网团队

</div>
