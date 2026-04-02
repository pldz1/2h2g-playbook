# 📡 ds-proxy — Docker 部署笔记

ds-proxy 是一个跑在服务器上的代理服务，基于 clash 内核，支持规则分流、全局代理、直连等模式。体积小、配置简单，部署在本地或云服务器上都能用。


## ⚠️ 暴露公网请注意

如果将服务暴露在公网，可能会面临扫描或攻击的风险。在这种情况下，**Clash 占用的内存可能会不断增长**，最终可能撑满云服务器资源。

为帮助监控资源使用，我们新增了 **ds-proxy-report.sh** 脚本：

```bash
sudo -E ./ds-proxy-report.sh        # 运行一次
sudo -E ./ds-proxy-report.sh --watch # 实时监控，每隔 30 秒刷新
```

它可以检测 IP 占用情况及容器健康状态。

同时，Clash 内核已更新，可通过以下命令查看版本：

```bash
./src/bin/amd64 -v
```

💡 **建议**：如果服务可能被攻击或出现高并发流量，请在云服务器端做好资源限制和安全防护配置，避免因内存占用过高导致系统崩溃。


---

## 项目文件

```
ds-proxy/
├── config.yaml.copy          # 配置模板，不要直接改这个 (项目运行前先 cp config.yaml.copy config.yaml)
├── docker-compose.yaml.copy  # 核心，服务怎么跑都在这里定义 (项目运行前先 cp docker-compose.yaml.copy docker-compose.yaml)
├── ds-proxy-report.sh        # 新增检测脚本, 查看什么IP/连接占据了你的服务
├── Dockerfile                # 镜像构建文件
└── src/
    ├── bin/
    │   └── amd64             # clash 可执行文件（amd64 架构）
    ├── conf/
    │   ├── config.yaml       # 容器内运行时配置（由 volumes 挂载进来）
    │   ├── cache.db          # 运行时缓存，自动生成
    │   └── Country.mmdb      # IP 归属地数据库
    ├── dashboard/            # yacd 控制面板静态资源
    └── logs/                 # 日志目录（挂载到宿主机）
```

---

## 运行前准备

**第一步：拷贝配置模板**

```bash
cp config.yaml.copy config.yaml

cp docker-compose.yaml.copy docker-compose.yaml
```

**第二步：编辑 `config.yaml`，填入你自己的代理节点**

重点改这几个地方：

```yaml
# 控制面板访问密码，建议改掉
secret: 123456789

# 填入你的代理节点
proxies:
  - name: "your-proxy"
    type: ss         # 协议类型，按实际填
    server: x.x.x.x
    port: 443
    ...

# 配置代理组和规则
proxy-groups:
  - ...
rules:
  - ...
```

---

## 改 docker-compose.yaml

默认配置开箱即用，按需调整以下几项：

```yaml
services:
  ds-proxy:
    # ───────────────
    # 固定容器名字，避免 Docker 自动生成 ds-proxy-xxx
    # ───────────────
    container_name: ds-proxy

    # ───────────────
    # 使用官方轻量 Alpine 镜像，无需 Dockerfile 构建
    # ───────────────
    image: alpine:3.18

    # ───────────────
    # 容器重启策略
    # unless-stopped: 容器会在 Docker 启动时自动启动，手动停止后不再自动启动
    # ───────────────
    restart: unless-stopped

    # ───────────────
    # 挂载宿主机文件和目录
    # 1. Mihomo 可执行文件（挂载宿主机最新版本）
    # 2. 配置文件 config.yaml
    # 3. 日志目录（可写）
    # 注意：:ro 只读，:rw 可写
    # ───────────────
    volumes:
      - ./src:/root/src
      - ./config.yaml:/root/src/conf/config.yaml:ro   # 配置文件

    # ───────────────
    # 端口映射
    # 7890:7890 → HTTP/HTTPS 代理端口映射到宿主机
    # 如果启用 dashboard 控制面板，可解注释 9090:9090
    # ───────────────
    ports:
      - "7890:7890"   # HTTP/HTTPS 代理
      - "9090:9090"  # Dashboard 控制面板

    # ───────────────
    # 容器启动命令
    # -d 指定配置文件目录
    # 绝对路径保证容器内部能找到配置文件
    # ───────────────
    command: ["/root/src/bin/amd64", "-d", "/root/src/conf"]

    # ───────────────
    # 日志管理
    # 避免日志无限制增长占用磁盘
    # max-size: 每个日志文件最大 10MB
    # max-file: 保留最近 3 个日志文件
    # ───────────────
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

    # ───────────────
    # 内存限制，避免进程占用过多导致宿主机 OOM
    # mem_limit: 容器使用内存上限
    # memswap_limit: 禁用 swap
    # oom_kill_disable: 是否允许 OOM killer
    # ───────────────
    mem_limit: 128m
    memswap_limit: 512m
    oom_kill_disable: false

    # ───────────────
    # 内核 TCP 调优（应用在容器内部）
    # 优化高并发代理连接
    # net.ipv4.tcp_fin_timeout: FIN_WAIT1/2 状态持续时间
    # net.ipv4.tcp_tw_reuse: 允许 TIME_WAIT 连接重用
    # net.ipv4.tcp_keepalive_*: 保持长连接心跳
    # ───────────────
    sysctls:
      net.ipv4.tcp_fin_timeout: 15
      net.ipv4.tcp_tw_reuse: 1
      net.ipv4.tcp_keepalive_time: 60
      net.ipv4.tcp_keepalive_intvl: 10
      net.ipv4.tcp_keepalive_probes: 3

    # ───────────────
    # 可选：使用宿主机网络模式
    # 如果你希望端口映射完全透明，使用 network_mode: host
    # 注意：host 模式下 ports 不生效
    # ───────────────
    # network_mode: "host"
```

---

## 启动

```bash
docker compose up -d
```

验证是否正常运行：

```bash
docker ps
docker logs ds-proxy
```

测试代理是否通：

```bash
curl -x http://127.0.0.1:7890 https://www.google.com
```

---

## 停止

```bash
docker compose down
```

容器停掉，数据还在，`src/logs/` 和 `config.yaml` 不会删。

---

## 访问控制面板（Dashboard）

如果需要图形化管理界面，取消 `docker-compose.yaml` 里端口注释：

```yaml
ports:
  - "7890:7890"
  - "9090:9090"    # 取消这行注释
```

重启容器后，打开浏览器访问：

```
http://<服务器IP>:9090/ui
```

用 `config.yaml` 里设置的 `secret` 登录。

> ⚠️ 云服务器记得放行防火墙端口和配置入站规则。

---

## 切换代理模式

在 `config.yaml` 里修改 `mode` 字段：

| 模式 | 说明 |
|---|---|
| `rule` | 按规则分流（推荐） |
| `global` | 全部走代理 |
| `direct` | 全部直连，不走代理 |

改完后重启容器生效：

```bash
docker compose restart
```

---

## 日志管理

日志文件挂载到宿主机 `./src/logs/`，容器重建后不丢失。

**查看实时日志：**

```bash
docker logs -f ds-proxy
```

**查看日志文件大小：**

```bash
du -sh ./src/logs/*
```

**Docker 内部 stdout 日志（已限制 30MB 上限）：**

```bash
sudo du -sh $(sudo docker inspect --format='{{.LogPath}}' ds-proxy)
```

**手动清空 stdout 日志（容器不会中断）：**

```bash
sudo truncate -s 0 $(sudo docker inspect --format='{{.LogPath}}' ds-proxy)
```

---

## 常见问题

**代理连不上**
检查 `config.yaml` 里的节点信息是否正确，查看日志排查：
```bash
docker logs ds-proxy
```

**端口冲突**
把 `docker-compose.yaml` 里 `7890:7890` 左边的端口改掉，比如 `7891:7890`。

**配置改了不生效**
`config.yaml` 以只读方式挂载进容器，修改后需要重启：
```bash
docker compose restart
```

**容器越来越大**
检查 Docker stdout 日志大小（已在 `docker-compose.yaml` 中限制）：
```bash
sudo du -sh $(sudo docker inspect --format='{{.LogPath}}' ds-proxy)
```
如果已经很大，用 `truncate` 命令清空即可（见上方日志管理章节）。

**想换架构（非 amd64）**
替换 `src/bin/` 下的可执行文件为对应架构版本，同步修改 `docker-compose.yaml` 里的 `command` 字段。

---

## 链接

- clash 文档：https://clash.wiki
- yacd Dashboard：https://github.com/haishanh/yacd
- Docker 文档：https://docs.docker.com/compose