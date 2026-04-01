# 📡 ds-proxy — Docker 部署笔记

ds-proxy 是一个跑在服务器上的代理服务，基于 clash 内核，支持规则分流、全局代理、直连等模式。体积小、配置简单，部署在本地或云服务器上都能用。

---

## 项目文件

```
ds-proxy/
├── config.yaml.copy          # 配置模板，不要直接改这个 (项目运行前先 cp config.yaml.copy config.yaml)
├── docker-compose.yaml.copy  # 核心，服务怎么跑都在这里定义 (项目运行前先 cp docker-compose.yaml.copy docker-compose.yaml)
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
    image: ds-proxy:latest
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ds-proxy
    restart: unless-stopped

    volumes:
      # 挂载你的配置文件（只读）
      - ./config.yaml:/root/src/conf/config.yaml:ro
      # 日志持久化到宿主机，避免容器层膨胀
      - ./src/logs:/root/src/logs

    ports:
      - "7890:7890"    # HTTP/HTTPS 代理端口，左边可以改
      - "9090:9090"    # Dashboard 端口，需要用控制面板时取消注释

    command: ["/root/src/bin/amd64", "-d", "/root/src/conf"]

    # 日志大小限制，防止 Docker 日志文件无限增长
    logging:
      driver: "json-file"
      options:
        max-size: "10m"   # 单文件最大 10MB
        max-file: "3"     # 最多保留 3 个文件，共约 30MB
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