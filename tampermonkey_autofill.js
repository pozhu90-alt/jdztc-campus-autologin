// ==UserScript==
// @name         景德镇陶瓷大学校园网自动登录
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  自动填写校园网登录信息并提交
// @author       You
// @match        http://172.29.0.2/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';
    
    // ===== 配置区域 - 请修改以下信息 =====
    const CONFIG = {
        username: '你的学工号',          // 修改为你的学工号
        password: '你的密码',           // 修改为你的密码
        isp: '中国移动',               // 修改为你的运营商：中国移动/中国联通/中国电信/测试
        autoSubmit: true,              // 是否自动提交（true=自动提交，false=只填写不提交）
        delaySeconds: 2                // 自动提交延迟时间（秒）
    };
    
    // ===== 主要功能代码 =====
    
    function autoFillAndSubmit() {
        try {
            // 检查配置
            if (CONFIG.username === '你的学工号') {
                alert('请先在Tampermonkey脚本中配置你的学号和密码！');
                return;
            }

            // 查找用户名输入框
            let usernameField = null;
            
            const userInputs = document.querySelectorAll('input[placeholder*="学工号"], input[placeholder*="用户"], input[placeholder*="账号"]');
            for (let input of userInputs) {
                if (input.offsetParent !== null) {
                    usernameField = input;
                    break;
                }
            }
            
            if (!usernameField) {
                const textInputs = document.querySelectorAll('input[type="text"]');
                for (let input of textInputs) {
                    if (input.offsetParent !== null && !input.name.includes('captcha')) {
                        usernameField = input;
                        break;
                    }
                }
            }
            
            if (!usernameField) {
                usernameField = document.querySelector('input[name="username"]') ||
                               document.querySelector('input[name="user"]') ||
                               document.querySelector('input[name="DDDDD"]');
            }

            if (usernameField) {
                usernameField.value = CONFIG.username;
                usernameField.dispatchEvent(new Event('input', { bubbles: true }));
                usernameField.dispatchEvent(new Event('change', { bubbles: true }));
                usernameField.focus();
            }

            // 查找密码输入框
            let passwordField = null;
            
            const pwdInputs = document.querySelectorAll('input[placeholder*="密码"], input[type="password"]');
            for (let input of pwdInputs) {
                if (input.offsetParent !== null) {
                    passwordField = input;
                    break;
                }
            }
            
            if (!passwordField) {
                passwordField = document.querySelector('input[name="upass"]') ||
                               document.querySelector('input[name="password"]') ||
                               document.querySelector('input[name="pwd"]') ||
                               document.querySelector('input[name="passwd"]');
            }

            if (passwordField) {
                passwordField.value = CONFIG.password;
                passwordField.dispatchEvent(new Event('input', { bubbles: true }));
                passwordField.dispatchEvent(new Event('change', { bubbles: true }));
                passwordField.focus();
            }

            // 查找运营商选择框
            const ispSelect = document.querySelector('select[name="isp"]') ||
                             document.querySelector('select[name="operator"]') ||
                             document.querySelector('select[name="service"]') ||
                             document.querySelector('select') ||
                             document.querySelector('[name*="运营商"]');

            if (ispSelect) {
                for (let i = 0; i < ispSelect.options.length; i++) {
                    const option = ispSelect.options[i];
                    if (option.text.includes(CONFIG.isp) || option.value.includes(CONFIG.isp)) {
                        ispSelect.selectedIndex = i;
                        ispSelect.dispatchEvent(new Event('change', { bubbles: true }));
                        break;
                    }
                }
            }
            
            // 自动提交
            if (CONFIG.autoSubmit) {
                setTimeout(() => {
                    // 查找登录按钮
                    let loginButton = null;
                    
                    const buttons = document.querySelectorAll('button, input[type="submit"], input[type="button"]');
                    for (let btn of buttons) {
                        if (btn.offsetParent !== null && 
                            (btn.textContent.includes('登录') || 
                             btn.value === '登录' || 
                             btn.value === 'Login')) {
                            loginButton = btn;
                            break;
                        }
                    }
                    
                    if (!loginButton) {
                        loginButton = document.querySelector('input[value="登录"]') ||
                                     document.querySelector('button[type="submit"]') ||
                                     document.querySelector('input[type="submit"]') ||
                                     buttons[0];
                    }

                    if (loginButton) {
                        loginButton.click();
                        
                        // 登录成功后关闭窗口
                        setTimeout(() => {
                            // 多种关闭条件，更宽松的判断
                            if (window.opener || window.parent !== window) {
                                window.close();
                            } else if (document.body.innerText.includes('登录成功') || 
                                      document.body.innerText.includes('认证成功') ||
                                      document.body.innerText.includes('成功') ||
                                      document.body.innerText.includes('欢迎') ||
                                      window.location.href.includes('success')) {
                                window.close();
                            }
                        }, 2000);
                    }
                }, CONFIG.delaySeconds * 1000);
            }
            
        } catch (error) {
            // 忽略错误
        }
    }
    
    function init() {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', init);
            return;
        }
        setTimeout(autoFillAndSubmit, 1000);
    }
    
    init();

})();