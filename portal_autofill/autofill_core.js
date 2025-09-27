// Portal Autofill Core with Enhanced Diagnostics
(function injectAutofill(config){
	try {
		const log = [];
		const addLog = (msg) => { log.push(msg); console.log('[AutoFill]', msg); };
		
		addLog('脚本开始执行，配置: ' + JSON.stringify(config));
		
		const wait = ms => new Promise(r => setTimeout(r, ms));
		const until = async (fn, timeoutMs=15000, step=300) => {
			const t0 = Date.now();
			let v;
			while (Date.now() - t0 < timeoutMs) { v = fn(); if (v) return v; await wait(step); }
			return null;
		};
		const getParam = (k) => {
			try { const m = new URL(location.href).searchParams.get(k); return m || ''; } catch(e){ return ''; }
		};
		const jsonp = (url, cbName) => new Promise((resolve) => {
			try {
				const name = cbName || ('cb' + Math.floor(Math.random()*1e8));
				window[name] = (data) => { resolve({ ok:true, data }); try{ delete window[name]; }catch(e){} };
				const u = url.replace(/callback=[^&]*/,'callback='+name);
				const s = document.createElement('script');
				s.src = u; s.async = true; s.onerror = () => resolve({ ok:false });
				document.head.appendChild(s);
				setTimeout(() => resolve({ ok:false, timeout:true }), 8000);
			}catch(e){ resolve({ ok:false, error:String(e) }); }
		});

		// ===== 人类鼠标/键盘模拟 =====
		const fireMouse = (el, type, x, y) => {
			const evt = new MouseEvent(type, { bubbles:true, cancelable:true, view:window, clientX:x, clientY:y, button:0 });
			el.dispatchEvent(evt);
		};

		const pressEnter = async (el) => {
			if (!el) return;
			try {
				const kd = new KeyboardEvent('keydown',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true});
				const kp = new KeyboardEvent('keypress',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true});
				const ku = new KeyboardEvent('keyup',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true});
				el.dispatchEvent(kd); el.dispatchEvent(kp); el.dispatchEvent(ku);
				addLog('模拟按下 Enter 键');
			} catch(e) { addLog('pressEnter 异常: '+e.message); }
		};

		const simulateMouseClick = async (el) => {
			if (!el) return;
			const r = el.getBoundingClientRect();
			const x = Math.floor(r.left + r.width / 2);
			const y = Math.floor(r.top + Math.min(r.height / 2, r.height - 2));
			fireMouse(el, 'mouseover', x, y);
			fireMouse(el, 'mousemove', x, y);
			fireMouse(el, 'mousedown', x, y);
			if (typeof el.focus === 'function') el.focus();
			await wait(40);
			fireMouse(el, 'mouseup', x, y);
			fireMouse(el, 'click', x, y);
			await wait(30);
		};
		const simulateType = async (el, text) => {
			try{
				await simulateMouseClick(el);
				el.value = '';
				for (const ch of String(text)){
					el.dispatchEvent(new KeyboardEvent('keydown',{key:ch,bubbles:true}));
					el.value += ch;
					el.dispatchEvent(new InputEvent('input',{bubbles:true}));
					el.dispatchEvent(new KeyboardEvent('keyup',{key:ch,bubbles:true}));
				}
				el.dispatchEvent(new Event('change',{bubbles:true}));
				try { el.blur(); } catch(e) {}
				addLog(`模拟键入完成: ${el.tagName}[${el.name||el.id||'unnamed'}]`);
			}catch(e){ addLog('simulateType 异常: '+e.message); }
		};

		const setValue = async (el, val) => {
			try{
				el.value = val;
				el.dispatchEvent(new Event('input', {bubbles:true}));
				el.dispatchEvent(new Event('change', {bubbles:true}));
				addLog(`设置元素值: ${el.tagName}[${el.name||el.id||'unnamed'}] = "${val}"`);
				// 再模拟真实键入一遍，触发依赖按键的脚本
				await simulateType(el, val);
			}catch(e){ addLog('setValue 异常: '+e.message); }
		};

        function analyzePageStructure() {
            const counts = {
                inputs: document.querySelectorAll('input').length,
                buttons: document.querySelectorAll('button, input[type="submit"], input[type="button"]').length,
                selects: document.querySelectorAll('select').length,
                forms: document.querySelectorAll('form').length
            };
            return counts;
        }

		function pickVisible(selectorList, purpose) {
			addLog(`查找${purpose}元素，选择器: ${selectorList.join(', ')}`);
			for (const sel of selectorList) {
				const nodes = document.querySelectorAll(sel);
				addLog(`选择器 "${sel}" 找到 ${nodes.length} 个元素`);
				for (const n of nodes) {
					if (n && n.offsetParent !== null) {
						addLog(`找到可见的${purpose}元素: ${n.tagName}[${n.name||n.id||'unnamed'}]`);
						return n;
					}
				}
			}
			addLog(`未找到可见的${purpose}元素`);
			return null;
		}

        // 已明确要求：无论页面是否存在运营商控件，用户名均不追加后缀

		async function loginViaEportal(finalUser, pwd){
			try {
				const ip = getParam('userip');
				const acip = getParam('wlanacip');
				const acname = getParam('wlanacname');
				const origin = location.origin || (location.protocol + '//' + location.host);
				const cb = 'dr1003';
				const qs = `c=Portal&a=login&callback=${cb}&login_method=1&user_account=%2C0%2C${encodeURIComponent(finalUser)}&user_password=${encodeURIComponent(pwd||'')}&wlan_user_ip=${encodeURIComponent(ip)}&wlan_user_ipv6=&wlan_user_mac=000000000000&wlan_ac_ip=${encodeURIComponent(acip)}&wlan_ac_name=${encodeURIComponent(acname)}&jsVersion=3.3.2&v=${Date.now()}`;
				const url = `${origin}/eportal/?${qs}`;
				addLog('并行触发 eportal 登录接口: ' + url);
				const res = await jsonp(url, cb);
				if (res && res.ok) {
					const text = JSON.stringify(res.data||{});
					const ok = /"result"\s*:\s*"ok"|res(Code|code)\s*[:=]\s*0/i.test(text);
					addLog('eportal 返回: ' + text);
					return !!ok;
				}
				return false;
			}catch(e){ addLog('eportal 直连异常: ' + e.message); return false; }
		}

		async function run(){
			addLog('开始页面分析...');
			
			// 分析页面结构
            const pageStructure = analyzePageStructure();
			addLog('页面结构分析完成:');
            addLog(`- 输入框: ${pageStructure.inputs} 个`);
            addLog(`- 按钮: ${pageStructure.buttons} 个`);
            addLog(`- 选择框: ${pageStructure.selects} 个`);
            addLog(`- 表单: ${pageStructure.forms} 个`);
			
			// 等待页面动态元素出现
			addLog('等待页面元素加载...');
			await until(() => document.querySelector('input[name="DDDDD"], input[name="upass"], button, select'));
			addLog('页面元素已就绪');
			
            // 查找用户名字段
			addLog('=== 开始查找用户名字段 ===');
			let userField = pickVisible([
				'input[placeholder*="学工号"]',
				'input[placeholder*="用户"]',
				'input[placeholder*="账号"]',
				'input[name="username"]',
				'input[name="user"]',
				'input[name="DDDDD"]',
				'input[type="text"]:not([name*="captcha"])'
			], '用户名');
			
			if (!userField) {
				addLog('尝试备用用户名选择器...');
				userField = document.querySelector('input[name="DDDDD"]');
				if (userField) addLog('通过备用选择器找到用户名字段');
			}
			
			if (userField && config.username) { 
				// 不再自动追加后缀，JCU（无运营商选择）场景使用原始学号
				await setValue(userField, String(config.username));
				addLog('✅ 用户名设置成功');
			} else {
				addLog('❌ 用户名设置失败: 字段=' + (userField ? '找到' : '未找到') + ', 配置=' + (config.username || '空'));
			}

			// 查找密码字段
			addLog('=== 开始查找密码字段 ===');
			let pwdField = pickVisible([
				'input[type="password"]',
				'input[name="upass"]',
				'input[name="password"]',
				'input[name="pwd"]',
				'input[name="passwd"]'
			], '密码');
			
			if (!pwdField) {
				addLog('尝试备用密码选择器...');
				pwdField = document.querySelector('input[name="upass"]');
				if (pwdField) addLog('通过备用选择器找到密码字段');
			}
			
			if (pwdField && config.password) {
				await setValue(pwdField, config.password);
				addLog('✅ 密码设置成功');
			} else {
				addLog('❌ 密码设置失败: 字段=' + (pwdField ? '找到' : '未找到') + ', 配置=' + (config.password ? '已提供' : '空'));
			}

			// 查找运营商选择
			addLog('=== 开始查找运营商字段 ===');
            const ispSel = pickVisible([
                'select[name="ISP_select"]',
                'select[name="isp"]',
                'select[name="operator"]',
                'select[name="service"]',
                'select'
            ], '运营商选择框');
			
			if (ispSel && config.isp) {
				addLog('找到运营商选择框，尝试设置...');
				const target = document.querySelector('select[name="ISP_select"]') || ispSel;
                const synonyms = (() => {
                    if (/联通|unicom/i.test(config.isp)) return ['联通','中国联通','unicom','lt','chinaunicom'];
                    if (/电信|telecom|ctcc/i.test(config.isp)) return ['电信','中国电信','telecom','ctcc','dx'];
                    if (/移动|cmcc|yd/i.test(config.isp)) return ['移动','中国移动','cmcc','yd','china mobile'];
                    return [String(config.isp)];
                })();
                let picked = false;
				await simulateMouseClick(target);
                for (let i=0;i<target.options.length;i++){
                    const opt = target.options[i];
                    const txt = (opt.text||'') + ' ' + (opt.value||'');
                    if (synonyms.some(s => new RegExp(s,'i').test(txt))) {
                        target.selectedIndex = i;
                        picked = true;
                        addLog('匹配到运营商选项: ' + (opt.text||opt.value));
                        break;
                    }
                }
                if (!picked) addLog('未找到匹配的运营商选项，维持默认');
				target.dispatchEvent(new Event('input', {bubbles:true}));
                target.dispatchEvent(new Event('change', {bubbles:true}));
                addLog('✅ 运营商设置完成');
			} else if (!ispSel && config.isp) {
				addLog('未找到下拉框，尝试单选按钮...');
				const radios = Array.from(document.querySelectorAll('input[type="radio"]'));
				const labels = Array.from(document.querySelectorAll('label, span, div'));
				addLog(`找到 ${radios.length} 个单选按钮, ${labels.length} 个标签`);
				
				let picked = false;
				for (const lab of labels){
					const txt = (lab.textContent||'').trim();
					if (/移动|联通|电信|校园用户|校园其他/.test(txt) && new RegExp(config.isp).test(txt)){
						addLog(`点击匹配标签: "${txt}"`);
						lab.click();
						picked = true; 
						break;
					}
				}
				
				if (!picked){
					addLog('通过标签未找到，尝试按value/id匹配...');
					for (const r of radios){
						const id = r.value || r.id || '';
						if ((/lt/.test(id) && /联通|unicom/i.test(config.isp)) || 
							(/dx|ctcc/.test(id) && /电信|telecom/i.test(config.isp)) || 
							(/yd|cmcc/.test(id) && /移动|cmcc/i.test(config.isp))) { 
							addLog(`点击匹配单选按钮: ${id}`);
							r.click(); 
							picked = true;
							break; 
						}
					}
				}
				
				if (picked) {
					addLog('✅ 运营商单选按钮设置成功');
				} else {
					addLog('❌ 运营商设置失败，未找到匹配项');
				}
			}

            // 极简快速：最短 300ms 即提交
            const delay = Math.max(200, Number(config.delayMs||0) || 0);
            addLog(`等待 ${delay}ms 后提交...`);
            await wait(delay);

			// 查找并点击登录按钮
			addLog('=== 开始查找登录按钮 ===');
			let clicked = false;
			
			// 严格模拟人工点击，不调用页面全局快捷函数
			
			if (!clicked){
				addLog('查找可见的登录按钮...');
				const nodeSets = [
					document.querySelectorAll('button, input[type="submit"], input[type="button"]'),
					document.querySelectorAll('a[href*="login" i], a[onclick*="login" i], a[href*="denglu" i]'),
					document.querySelectorAll('[id*="login" i], [class*="login" i], [id*="denglu" i], [class*="denglu" i]'),
					document.querySelectorAll('div[role="button"]')
				];
				const seen = new Set();
				const buttons = [];
				nodeSets.forEach(ns => Array.from(ns).forEach(n => { if (n && !seen.has(n)) { seen.add(n); buttons.push(n); }}));
				addLog(`候选可点击元素: ${buttons.length}`);
				
				for (const btn of buttons){
					const label = ((btn.textContent||'') + ' ' + (btn.value||'') + ' ' + (btn.getAttribute('id')||'') + ' ' + (btn.getAttribute('class')||''));
					const cs = getComputedStyle(btn);
					const isVisible = btn.offsetParent !== null && cs.visibility !== 'hidden' && cs.display !== 'none';
					addLog(`候选: "${label.trim().slice(0,60)}" 可见:${isVisible}`);
					
					if (isVisible && (/登录|Login|确定|submit|signin|sign in|登陆/i.test(label))) { 
						addLog(`✅ 点击登录按钮: "${label.trim().slice(0,60)}"`);
						await simulateMouseClick(btn);
						clicked = true; 
						break; 
					}
				}
			}

			// 若未找到按钮，尝试在密码框上模拟回车提交
			if (!clicked) { await pressEnter(pwdField || userField); clicked = true; addLog('使用回车触发表单'); }

            // 兜底：若依然未触发，则尝试直接提交表单
            if (!clicked) {
                addLog('未能识别到按钮/函数，尝试直接表单提交...');
                let form = document.querySelector('form[action*="login"], form[name*="login"], form[id*="login"]');
                if (!form) form = document.forms && document.forms[0];
                if (form && typeof form.submit === 'function') {
                    try { form.submit(); clicked = true; addLog('✅ 直接提交表单成功'); } catch(e) { addLog('表单提交失败: ' + e.message); }
                } else {
                    addLog('未找到可提交的表单');
                }
            }

			// 无论点击是否成功，立即并行触发一次 eportal 接口确认，贴近人工浏览器行为
			let directOk = false;
			try {
				// 直接使用学号原值作为账号，不追加后缀
				directOk = await loginViaEportal(String(config.username||''), config.password||'');
				if (directOk) addLog('✅ eportal 接口确认成功');
			} catch(e) {}

            // 等待成功信号（同页或新页不一定能感知，这里只做同页增益）
			let success = false;
            try {
                success = !!(await until(() => {
                    const txt = document.body && (document.body.innerText || '');
                    const okTxt = /成功登录|已成功登录|认证成功|登录成功|联网成功|欢迎|Success/i.test(txt);
                    const okUrl = /success|loginSuccess|auth_success|a11\.htm/i.test(location.href || '');
                    const logoutBtn = /注销|下线|Logout/i.test(txt);
                    return okTxt || okUrl || logoutBtn;
                }, 6000, 300));
            } catch(e) {}



            // 成功后主动探测一次外网（不刷新页面，避免回到登录态）
            if (success || directOk) {
                addLog('✅ 侦测到成功信号，触发外网探测以完成放行...');
                try { await fetch('http://www.gstatic.com/generate_204', {mode:'no-cors', cache:'no-store'}); } catch(e) {}
                await wait(500);
            }

            addLog('=== 脚本执行完成 ===');
            addLog(`登录按钮点击: ${clicked ? '成功' : '失败'}`);
            
			return { 
                ok: true, 
				clicked, 
                success,
                log: log,
                pageStructure: pageStructure,
                userField: userField ? `${userField.tagName}[${userField.name||userField.id}]` : null,
                pwdField: pwdField ? `${pwdField.tagName}[${pwdField.name||pwdField.id}]` : null,
                ispField: ispSel ? `${ispSel.tagName}[${ispSel.name||ispSel.id}]` : null
            };
		}

		return run();
	} catch (e){
		addLog('脚本执行异常: ' + e.message);
		return { 
			ok: false, 
			error: String(e),
			log: log
		};
	}
})

