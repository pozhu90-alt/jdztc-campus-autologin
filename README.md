# 校园网认证工具 - 全面版本（CDP 无感认证）

本版本以“仅用 CDP（Chromium DevTools Protocol）在页面内模拟人操作”的方式完成 Portal 认证，不手写 GET/POST 参数，确保跨学校通用与稳定放行。支持开机即连（计划任务）、多 SSID、在线规则热更新（占位）、WPF GUI（占位）。

## 核心能力
- CDP 页面自动化：后台/无头启动 Edge/Chromium，在页面中执行表单填充与点击逻辑（与浏览器扩展一致）。
- 开机即连：通过计划任务在用户登录后静默运行，进入桌面时已联网。
- 多 SSID：可配置多个校园网名称，自动轮询连接。
- 安全存储：使用 Windows DPAPI 加密保存密码，日志脱敏。
- Portal 检测：基于 NCSI/generate_204 劫持识别与外网验证。

## 目录结构
```
06-全面版本/
  README.md
  config.json
  portal_autofill/
    autofill_core.js
  scripts/
    start_auth.ps1               ← 主入口（编排 Wi‑Fi→检测→CDP 注入→验证）
    modules/
      cdp.psm1                   ← 纯原生 CDP 客户端（WebSocket）
      wifi.psm1                  ← 打开 WLAN、连接 SSID、获取网卡信息
      netdetect.psm1             ← 劫持检测与外网验证
      security.psm1              ← DPAPI 密码加解密与存取
  tasks/
    install_autostart.ps1        ← 注册计划任务，开机即连
  gui/                            ← WPF 引导（占位，后续补充）
```

## 使用步骤（首版 MVP）
1) 配置 `config.json` 中的学号（username）与 SSID 列表（wifi_names）。
2) 运行一次安全存储（临时方法）：
   - 启动 PowerShell，执行：
     - `Import-Module ./scripts/modules/security.psm1`
     - `Save-Secret -Id "CampusPortalCredential" -Secret (Read-Host -AsSecureString "输入门户密码")`
3) 交互测试：
   - `./scripts/start_auth.ps1`（默认静默执行，日志见同目录 `campus_network.log`）
4) 开机即连：
   - `./tasks/install_autostart.ps1`（创建“用户登录后、延迟 7s、最高权限、隐藏”计划任务）

## 默认流程
1. 打开 WLAN 服务、启用 Wi‑Fi 网卡、连接配置 SSID（开放网络自动生成 Profile）。
2. 劫持检测：访问 `http://www.gstatic.com/generate_204`（禁重定向）。
3. 启动 Edge（远程调试端口），创建页面并导航到 `generate_204`（被门户重定向）。
4. 在页面内注入 `portal_autofill/autofill_core.js` 并执行自动填充与提交。
5. 等待 3–5 秒，二次外网验证；成功则关闭页面与浏览器。

## 注意事项
- 需要 Windows 10/11 + PowerShell 5.1+；系统需具备 Edge 或任一 Chromium 可用 CDP。
- 首版聚焦认证 MVP，GUI/WPF 与规则热更新稍后补全。
- 若杀软/企业策略禁止无头浏览器，请将本程序加入白名单。

## 日志
- 默认日志：`06-全面版本/campus_network.log`
- 失败时可打包日志与网络诊断信息（后续“诊断工具”补充）。


