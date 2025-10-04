// 小瓷连网 - 云函数服务（Supabase 免费版 - 使用axios）
const https = require('https');

// ========== 配置区 ==========
const CONFIG = {
    latestVersion: "1.0.0",
    releaseDate: "2025-10-03",
    downloadUrl: "https://github.com/你的用户名/仓库名/releases/download/v1.0.0/小瓷连网.exe",
    downloadSize: "5.6 MB",
    updateLog: "【v1.0.0 正式版】\n✨ 首个正式发布版本\n🎨 精美的小瓷风格界面\n🚀 自动连接校园网\n📊 匿名使用统计\n🔄 在线版本更新",
    forceUpdate: false,
};

// ========== Supabase 配置 ==========
const SUPABASE_URL = "https://hehlypeyunpjmvmzuaqg.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhlaGx5cGV5dW5wam12bXp1YXFnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk0ODUwNTYsImV4cCI6MjA3NTA2MTA1Nn0.yYR06J8KEe2Kg-ab3ZgDLT87SLy058Hojx5lvwOQBSk";

// 辅助函数：发送HTTPS请求
function httpsRequest(url, options = {}) {
    return new Promise((resolve, reject) => {
        const urlObj = new URL(url);
        const reqOptions = {
            hostname: urlObj.hostname,
            path: urlObj.pathname + urlObj.search,
            method: options.method || 'GET',
            headers: options.headers || {},
        };

        const req = https.request(reqOptions, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    try {
                        resolve({ 
                            ok: true, 
                            data: JSON.parse(data), 
                            headers: res.headers,
                            statusCode: res.statusCode
                        });
                    } catch {
                        resolve({ ok: true, data: data, headers: res.headers, statusCode: res.statusCode });
                    }
                } else {
                    reject(new Error(`HTTP ${res.statusCode}: ${data}`));
                }
            });
        });

        req.on('error', reject);
        if (options.body) {
            req.write(options.body);
        }
        req.end();
    });
}

// ========== 主函数 ==========
exports.main_handler = async (event, context) => {
    console.log("收到请求:", event.path, event.httpMethod);
    
    const path = event.path || '/';
    const method = event.httpMethod || 'GET';
    
    const headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
    };
    
    try {
        // ===== 统计接口 =====
        if (path === '/stats' && method === 'POST') {
            const body = JSON.parse(event.body || '{}');
            const deviceId = body.id || 'unknown';
            const version = body.v || '0.0.0';
            const os = body.os || 'Unknown';
            const now = new Date().toISOString();
            
            // 检查用户是否存在
            const checkResult = await httpsRequest(
                `${SUPABASE_URL}/rest/v1/users?device_id=eq.${deviceId}`,
                {
                    method: 'GET',
                    headers: {
                        'apikey': SUPABASE_KEY,
                        'Authorization': `Bearer ${SUPABASE_KEY}`,
                    }
                }
            );
            
            const existingUsers = checkResult.data;
            
            if (existingUsers && existingUsers.length > 0) {
                // 更新现有用户
                const user = existingUsers[0];
                await httpsRequest(
                    `${SUPABASE_URL}/rest/v1/users?device_id=eq.${deviceId}`,
                    {
                        method: 'PATCH',
                        headers: {
                            'apikey': SUPABASE_KEY,
                            'Authorization': `Bearer ${SUPABASE_KEY}`,
                            'Content-Type': 'application/json',
                            'Prefer': 'return=minimal'
                        },
                        body: JSON.stringify({
                            last_seen: now,
                            version: version,
                            os: os,
                            launch_count: (user.launch_count || 0) + 1
                        })
                    }
                );
            } else {
                // 创建新用户
                await httpsRequest(
                    `${SUPABASE_URL}/rest/v1/users`,
                    {
                        method: 'POST',
                        headers: {
                            'apikey': SUPABASE_KEY,
                            'Authorization': `Bearer ${SUPABASE_KEY}`,
                            'Content-Type': 'application/json',
                            'Prefer': 'return=minimal'
                        },
                        body: JSON.stringify({
                            device_id: deviceId,
                            first_seen: now,
                            last_seen: now,
                            version: version,
                            os: os,
                            launch_count: 1
                        })
                    }
                );
            }
            
            // 记录启动历史
            await httpsRequest(
                `${SUPABASE_URL}/rest/v1/launches`,
                {
                    method: 'POST',
                    headers: {
                        'apikey': SUPABASE_KEY,
                        'Authorization': `Bearer ${SUPABASE_KEY}`,
                        'Content-Type': 'application/json',
                        'Prefer': 'return=minimal'
                    },
                    body: JSON.stringify({
                        device_id: deviceId,
                        version: version,
                        timestamp: now,
                        os: os
                    })
                }
            );
            
            console.log(`统计记录: ${deviceId} (v${version})`);
            
            return {
                statusCode: 200,
                headers: headers,
                body: JSON.stringify({ success: true })
            };
        }
        
        // ===== 版本检查接口 =====
        if (path === '/version' && method === 'GET') {
            return {
                statusCode: 200,
                headers: headers,
                body: JSON.stringify(CONFIG)
            };
        }
        
        // ===== 统计数据查询接口 =====
        if (path === '/dashboard' && method === 'GET') {
            const now = new Date();
            const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
            const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
            const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();
            
            // 获取所有用户
            const usersResult = await httpsRequest(
                `${SUPABASE_URL}/rest/v1/users?select=*`,
                {
                    headers: {
                        'apikey': SUPABASE_KEY,
                        'Authorization': `Bearer ${SUPABASE_KEY}`,
                    }
                }
            );
            
            const users = usersResult.data || [];
            
            // 获取所有启动记录
            const launchesResult = await httpsRequest(
                `${SUPABASE_URL}/rest/v1/launches?select=count`,
                {
                    method: 'GET',
                    headers: {
                        'apikey': SUPABASE_KEY,
                        'Authorization': `Bearer ${SUPABASE_KEY}`,
                        'Prefer': 'count=exact'
                    }
                }
            );
            
            // 从响应头获取总数
            const contentRange = launchesResult.headers['content-range'];
            const totalLaunches = contentRange ? parseInt(contentRange.split('/')[1] || 0) : users.reduce((sum, u) => sum + (u.launch_count || 0), 0);
            
            // 计算活跃用户
            const oneDayAgoTime = new Date(oneDayAgo).getTime();
            const sevenDaysAgoTime = new Date(sevenDaysAgo).getTime();
            const thirtyDaysAgoTime = new Date(thirtyDaysAgo).getTime();
            
            let dau = 0, wau = 0, mau = 0;
            const versionDistribution = {};
            
            users.forEach(user => {
                const lastSeenTime = new Date(user.last_seen).getTime();
                if (lastSeenTime >= oneDayAgoTime) dau++;
                if (lastSeenTime >= sevenDaysAgoTime) wau++;
                if (lastSeenTime >= thirtyDaysAgoTime) mau++;
                
                const v = user.version || '0.0.0';
                versionDistribution[v] = (versionDistribution[v] || 0) + 1;
            });
            
            const result = {
                totalUsers: users.length,
                totalLaunches: totalLaunches,
                dau: dau,
                wau: wau,
                mau: mau,
                versionDistribution: versionDistribution,
                latestVersion: CONFIG.latestVersion,
                updateTime: now.toISOString()
            };
            
            console.log("统计数据:", result);
            
            return {
                statusCode: 200,
                headers: headers,
                body: JSON.stringify(result)
            };
        }
        
        // ===== 默认接口 =====
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'text/plain; charset=utf-8',
                'Access-Control-Allow-Origin': '*'
            },
            body: '小瓷连网云服务运行中（Supabase免费版 v2）✓'
        };
        
    } catch (error) {
        console.error("处理错误:", error);
        return {
            statusCode: 500,
            headers: headers,
            body: JSON.stringify({ 
                error: error.message,
                stack: error.stack 
            })
        };
    }
};

