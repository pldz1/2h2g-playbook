# 🖥️ ttyd 配置指南 — 2h2g 云服务器 Web 终端

> **ttyd** 是一个把终端通过浏览器共享出去的轻量级工具，无需 SSH 客户端，打开网页就能操作服务器。  
> 项目主页：https://github.com/tsl0922/ttyd

---

## 一、📦 下载 ttyd

Linux 推荐直接下载官方预编译二进制, 或者是 `apt/yum` 云服务器直接安装, 省去编译麻烦。

```bash
# 1. 去 releases 页面确认最新版本号（当前稳定版 1.7.7）
# 下载 x86_64 二进制（根据你的架构选择，服务器通常是 x86_64）
wget -O /usr/local/bin/ttyd \
  https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64

# 2. 赋予可执行权限
chmod +x /usr/local/bin/ttyd

# 3. 验证安装
ttyd --version

---

## 二、🔐 配置认证与端口

ttyd 通过命令行参数控制所有行为，核心参数说明如下：

| 参数 | 说明 | 示例 |
|------|------|------|
| `-p` | 监听端口 | `-p 7689` |
| `-i` | 绑定网卡 / IP，`0.0.0.0` 表示监听所有网卡 | `-i 0.0.0.0` |
| `-c` | Basic Auth 认证，格式 `用户名:密码` | `-c test:123` |
| `-W` | 允许客户端写入（默认只读，**必须加**才能操作终端） | `-W` |
| `-t` | 客户端选项，如字体大小 | `-t fontSize=16` |

**手动测试一下（前台运行）：**

```bash
/usr/bin/ttyd -i 0.0.0.0 -p 7689 -W -c test:123 -t fontSize=16 /bin/bash -l
```

## 云服务器测试一定要放行防火墙的端口和设置云服务器的出入站规则.

打开浏览器访问 `http://<你的服务器IP>:7689`，输入用户名 `test`、密码 `123` 即可进入终端。  
确认没问题后按 `Ctrl+C` 退出，接下来配置开机自启。

---


## 三、🚀 配置 systemd 开机自启

### 3.1 创建 service 文件

```bash
sudo vim /etc/systemd/system/ttyd.service
```

粘贴以下内容（**按需修改用户名、端口、账号密码**）：

```ini
[Unit]
Description=ttyd web terminal
After=network.target

[Service]
Type=simple
User=pldz1
WorkingDirectory=/home/pldz1
ExecStart=/usr/bin/ttyd -i 0.0.0.0 -p 7689 -W -c test:123 -t fontSize=16 /bin/bash -l
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

> **字段说明：**
> - `User=pldz1`：以 `pldz1` 用户身份运行，终端权限与该用户一致
> - `WorkingDirectory`：终端启动时的工作目录
> - `Restart=always`：进程崩溃后自动重启
> - `RestartSec=3`：重启前等待 3 秒

### 3.2 启用并启动服务

```bash
# 让 systemd 识别新文件
sudo systemctl daemon-reload

# 设置开机自启
sudo systemctl enable ttyd

# 立即启动
sudo systemctl start ttyd

# 查看运行状态
sudo systemctl status ttyd
```

看到 `Active: active (running)` 就说明成功了 ✅

---

## 四、🔄 修改配置后如何重载服务

每次修改 `/etc/systemd/system/ttyd.service` 之后，**必须按以下顺序执行**，否则改动不会生效：

```bash
# 第一步：重新加载 systemd 守护进程，让它读取最新的 service 文件
sudo systemctl daemon-reload

# 第二步：重启 ttyd 服务，使新配置生效
sudo systemctl restart ttyd

# 第三步（可选）：确认服务正常运行
sudo systemctl status ttyd
```

> ⚠️ **常见错误**：只执行 `restart` 而跳过 `daemon-reload`，此时 systemd 仍然使用旧的配置文件内容，修改不会生效。**两步缺一不可。**

---

## 五、🛠️ 常用管理命令速查

```bash
# 查看服务状态
sudo systemctl status ttyd

# 启动
sudo systemctl start ttyd

# 停止
sudo systemctl stop ttyd

# 重启（配置未改动时使用）
sudo systemctl restart ttyd

# 查看实时日志
sudo journalctl -u ttyd -f

# 查看最近 50 行日志
sudo journalctl -u ttyd -n 50
```

---

## 六、🔒 安全建议

1. **修改默认密码**：`-c test:123` 只是示例，生产环境务必换成强密码，如 `-c admin:Str0ng@Pass!`
2. **限制来源 IP**：安全组入站规则中，将来源从 `0.0.0.0/0` 改为你自己的固定 IP，大幅降低暴露风险
3. **建议配置 HTTPS**：在 ttyd 前面挂一个 Nginx 反向代理并配置 SSL 证书，避免账号密码明文传输

---

## 参考

- 官方仓库：https://github.com/tsl0922/ttyd
- 官方 Releases：https://github.com/tsl0922/ttyd/releases
- 使用示例 Wiki：https://github.com/tsl0922/ttyd/wiki/Example-Usage