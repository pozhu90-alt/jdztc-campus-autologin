# GUI 迁移和打包总结

## 完成时间
2025年10月1日

## 迁移内容

### 1. GUI 界面升级
- **原GUI**: `config_gui_new.ps1` (简洁版)
- **新GUI**: `config_gui_new copy.ps1` (陶瓷风格精美版)
- **最终文件**: `config_gui.ps1` (用于打包)

### 2. 新GUI特性
✨ **视觉设计**
- 陶瓷风格渐变背景 (米黄色 → 浅橙色)
- 左侧装饰面板，带圆形头像区域
- 现代化圆角按钮和输入框
- 自定义对话框（带渐变色和阴影效果）

🎨 **UI组件**
- 窗口控制按钮（最小化/最大化/关闭）使用圆形头像图片
- 装饰性文字（在对话框右上角旋转显示）
- 平滑渐变过渡层
- 个性化提示文本（"小瓷为主人连接网络耶！"等）

### 3. 保留的核心功能
所有原有的配置和业务逻辑均已完整迁移：
- ✅ 学工号和密码管理（带占位符检测）
- ✅ 登录延迟设置（0-3秒）
- ✅ ISP运营商选择（联通/电信/移动/无）
- ✅ Wi-Fi选择（学校网/校园网JCI）
- ✅ 信号强度阈值设置
- ✅ 浏览器选择（Edge/Chrome）
- ✅ 任务计划创建和删除
- ✅ 密码安全存储（DPAPI加密）

### 4. 图片资源
以下图片已嵌入到exe中：
- `avatar.png` (3.5 MB) - 主头像
- `minimize_avatar.png` (1.6 MB) - 最小化按钮头像
- `maximize_avatar.png` (1.4 MB) - 最大化按钮头像  
- `close_avatar.png` (1.5 MB) - 关闭按钮头像

### 5. 打包配置更新
修改了 `build/make_blank.ps1`，新增以下嵌入文件：
```powershell
$embed["$appData\\gui\\avatar.png"]
$embed["$appData\\gui\\minimize_avatar.png"]
$embed["$appData\\gui\\maximize_avatar.png"]
$embed["$appData\\gui\\close_avatar.png"]
```

### 6. 生成的文件
- **文件名**: `CampusNet_blank.exe`
- **大小**: 8,282,112 字节 (约 8 MB)
- **位置**: `dist\CampusNet_blank.exe`
- **生成时间**: 2025年10月1日 20:50:36
- **类型**: 空白版本（不包含预填账号密码）

## 使用说明

### 运行程序
1. 双击 `CampusNet_blank.exe`
2. 首次运行会自动解压文件到 `%APPDATA%\CampusNet`
3. 显示新的陶瓷风格GUI配置界面

### 配置步骤
1. 输入学工号
2. 输入数字化（云陶）密码
3. 设置登录延迟（推荐1秒）
4. 选择运营商（如需要）
5. 选择Wi-Fi模式
6. 点击"保存配置"或"保存并连接"

### 任务计划
- 程序会创建名为 `CampusPortalAutoConnect` 的计划任务
- 在用户登录时自动运行（带延迟）
- 需要管理员权限

## 技术改进

### 密码处理
- 增强的占位符检测（多重验证防止误判）
- 支持密码长度匹配的占位符显示
- 焦点事件自动清空占位符

### 窗口控制
- 无边框窗口设计
- 支持拖拽移动
- 自定义窗口控制按钮

### 对话框
- 渐变色彩区分（Info/Error/Warning/Question）
- 圆角边框和阴影效果
- 关闭按钮悬停效果

## 文件清单

### 核心文件
- `dist/config_gui.ps1` - 主GUI配置文件
- `dist/CampusNet_blank.exe` - 打包后的可执行文件
- `build/make_blank.ps1` - 更新后的打包脚本

### 图片资源
- `dist/avatar.png`
- `dist/minimize_avatar.png`
- `dist/maximize_avatar.png`
- `dist/close_avatar.png`

### 原始文件（保留）
- `dist/config_gui_new.ps1` - 原简洁版GUI
- `dist/config_gui_new copy.ps1` - 陶瓷风格GUI源文件

## 注意事项
1. 程序需要管理员权限才能创建计划任务
2. 图片文件会自动嵌入exe，无需单独分发
3. 所有配置保存在 `%APPDATA%\CampusNet\config.json`
4. 密码使用Windows DPAPI加密存储在 `secrets.json`

## 后续建议
- 可以根据需要替换头像图片（保持相同文件名）
- 可以调整窗口大小和颜色主题
- 可以添加更多装饰性元素

---
*迁移完成 ✅*

