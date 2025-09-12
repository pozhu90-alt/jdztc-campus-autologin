# 景德镇陶瓷大学校园网自动登录

一个简单的浏览器脚本，帮助景德镇陶瓷大学的学生自动登录校园网。

## 说明

每次连校园网都要手动输入学号密码选运营商很麻烦，于是写了这个脚本。

脚本会在登录页面自动填写你的信息并提交，登录成功后自动关闭页面。

## 使用方法

### 1. 安装 Tampermonkey

先装个 Tampermonkey 扩展：

- **Chrome**: [Chrome 网上应用店](https://chrome.google.com/webstore/detail/tampermonkey/dhdgffkkebhmkfjojejmpbldmpobfkfo)
- **Edge**: [Microsoft Edge 外接程序](https://microsoftedge.microsoft.com/addons/detail/tampermonkey/iikmkjmpaadaobahmlepeloendndfphd) 
- **Firefox**: [Firefox 附加组件](https://addons.mozilla.org/zh-CN/firefox/addon/tampermonkey/)

其他浏览器在扩展商店搜索 "Tampermonkey" 就行。

### 2. 添加脚本

1. 点击浏览器右上角的 Tampermonkey 图标
2. 选择 "管理面板"
3. 点击 "+" 创建新脚本
4. 把 `tampermonkey_autofill.js` 文件内容复制粘贴进去
5. 按 Ctrl+S 保存

或者直接把 `tampermonkey_autofill.js` 拖到 Tampermonkey 的编辑器窗口里。

### 3. 修改配置

编辑脚本开头的配置部分：

```javascript
const CONFIG = {
    username: '你的学工号',          // 改成你的学号
    password: '你的密码',           // 改成你的密码
    isp: '中国移动',               // 改成你的运营商
    autoSubmit: true,              // 是否自动提交
    delaySeconds: 2                // 延迟时间
};
```

运营商就三个选择：中国移动、中国联通、中国电信

### 4. 开始使用

1. 连接校园网 WiFi "JCI"
2. 打开浏览器随便访问个网页
3. 会自动跳转到登录页面
4. 脚本自动填写信息并登录
5. 成功后页面会自动关闭

## 常见问题

**脚本不工作？**
- 检查 Tampermonkey 有没有启用
- 确认脚本已经保存并启用
- 看看浏览器有没有禁用用户脚本

**自动填写失败？**
- 检查学号密码有没有写对
- 确认运营商选择正确

**登录不成功？**
- 先手动登录试试，确认账号密码没问题
- 检查网络连接

## 技术说明

- 支持主流浏览器：Chrome、Firefox、Edge、Safari 等
- 基于 Tampermonkey 用户脚本平台
- 只在校园网登录页面 (http://172.29.0.2/*) 运行
- 所有配置存储在本地，不会上传任何信息

## 免责声明

- 仅供学习交流使用
- 请遵守学校网络使用规定  
- 建议定期更换密码保护账户安全
- 使用后果自负

---

觉得有用的话给个 star 支持一下。