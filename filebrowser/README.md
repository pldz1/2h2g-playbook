# 📂 Filebrowser — Docker 部署笔记

Filebrowser 就是一个跑在服务器上的网页文件管理器，装好之后打开浏览器就能**上传下载、预览编辑文件**。 而且体积非常小, 这里把它部署在 2H2G 的云服务器上，当作个人文件管理入口用——轻量、够用、不占资源。

官方仓库：https://github.com/filebrowser/filebrowser

---

## 项目文件

```
filebrowser/
├── config/                  # 运行时配置，第一次启动后自动生成，不用管
├── database/                # SQLite 数据库，用户账号存在这里，同上
├── docker-compose.yaml.copy # 核心，服务怎么跑都在这里定义, 记得跑起来拷贝一个docker-compose.yaml作为你自己的
├── start.sh                 # 启动
├── stop.sh                  # 停止
└── clean.sh                 # 清库（删号删数据，慎用）
```

---

## 运行

1. 拷贝 `docker-compose.yaml` : `cp docker-compose.yaml.copy docker-compose.yaml`
2. 编辑 `docker-compose.yaml`
3. 运行: `docker compose up` 分离运行: `docker compose up -d`


---

## 跑起来之前，先确认一件事

**查一下你自己的用户 ID：**

```bash
id
```

会输出类似这样的东西：
```
uid=1001(pldz1) gid=1001(pldz1) groups=1001(pldz1)
```

把 `uid` 和 `gid` 那两个数字记下来。

---

**为什么要这么做？**

Docker 容器默认用 root 身份跑，如果让 root 去读写你的主目录，写出来的文件所有者就变成 root 了，然后你自己反而动不了那些文件，很烦。

`docker-compose.yaml` 里有一行 `user: "1001:1001"`，把这里改成你自己的 uid:gid，容器就会用你的身份操作文件，权限问题直接消失。

---

## 改 docker-compose.yaml

把下面这几个地方按实际情况改掉：

```yaml
services:
  filebrowser:
    image: filebrowser/filebrowser:v2.57.0
    container_name: filebrowser
    restart: unless-stopped

    # 改成你自己的 uid:gid，就是上面 id 命令查到的那两个数字
    user: "1001:1001"

    ports:
      # 左边是宿主机端口，想换就换，比如改成 8080:80
      # 右边的 80 是容器内部端口，不要动
      - "10060:80"

    volumes:
      # 把 /home/pldz1 换成你想通过网页管理的那个目录
      # 这个路径会变成 filebrowser 里的根目录
      - /home/pldz1:/srv

      # 下面这两行不用动，数据库和配置存到本地来
      - ./database:/database
      - ./config:/config

    entrypoint: ["/bin/sh", "-c"]
    command: >
      '
      if [ ! -f /database/filebrowser.db ]; then
        filebrowser config init --database /database/filebrowser.db &&

        # 改成你想要的管理员用户名和密码
        # 格式：users add <用户名> <密码> --perm.admin ...
        filebrowser users add test 123 --perm.admin --database /database/filebrowser.db;
      fi;
      exec /init.sh
        --database /database/filebrowser.db
        --root /srv
        --address 0.0.0.0
        --port 80
      '
```

---

**关于 command 里那段 if 判断：**

`if [ ! -f /database/filebrowser.db ]` 的意思是，只有数据库文件不存在的时候才初始化。

这样写是故意的——避免每次重启容器都把账号密码重置掉。第一次启动会建库、建账号，之后重启直接跳过这段，你改过的数据不会丢。

---

## 启动

```bash
bash start.sh
```

脚本会自动建好 `database/` 和 `config/` 目录，然后在后台拉起容器。

等几秒，打开浏览器访问：

## 云服务器测试一定要放行防火墙的端口和设置云服务器的出入站规则.

```
http://<服务器IP>:10060
```

用你刚才设置的账号密码登录就行了。

---

## 停止

```bash
bash stop.sh
```

容器停掉了，数据还在，`database/` 和 `config/` 里的东西不会删。下次 start 直接恢复。

---

## 清库（⚠️ 真的会删数据）

```bash
bash clean.sh
```

会删掉数据库和配置，账号全没了。脚本会让你确认一次，输 `y` 才会真的执行。

一般只有想完全重置、或者换账号密码的时候才用这个。

或者是你**需要修改用户名和密码**, 那就重新删除那个数据库.

---

## 几个常见的改动

**换端口**
把 `10060:80` 左边那个数字改掉就行，比如 `8888:80`，然后访问地址变成 `:8888`。

**换被管理的目录**
把 volumes 里 `/home/pldz1:/srv` 冒号左边的路径换掉，想管哪个目录就写哪个。

**改初始账号密码**
先跑一次 `clean.sh` 把旧数据清掉，在 `docker-compose.yaml` 里改好用户名密码，再 `start.sh` 重新初始化。

**升级版本**
把 `image` 那行的版本号改成新的（最新是 `v2.61.1`），然后：
```bash
bash stop.sh
sudo docker compose pull
bash start.sh
```

---

## 遇到问题

**页面 403 或者文件列表空白**
八成是 `user` 那个 uid:gid 写错了，或者挂载的目录对那个用户没有读权限。

**忘密码了**
跑 `clean.sh` 清一下，改好密码重新启动。

**想加更多用户**
登录管理员账号，进「设置 → 用户管理」，在界面里加就行，不用改配置文件。

**数据在哪**
`./database/filebrowser.db` 是 SQLite 数据库文件，账号权限都存这里。`./config/` 是运行时配置。这两个目录都在宿主机本地，容器删了数据还在。

---

## 链接

- 官方文档：https://filebrowser.org
- Docker 镜像：https://hub.docker.com/r/filebrowser/filebrowser
- 源码：https://github.com/filebrowser/filebrowser