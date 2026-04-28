# 📂 Git Folder Dashboard — 多仓库 Git 管理面板（轻量版）

Git Folder Dashboard 是一个跑在本地/服务器上的网页工具，用来**统一管理多个 Git 仓库的状态和操作**。

在线预览: [https://pldz1.com/io/git-folder-dashboard/](https://pldz1.com/io/git-folder-dashboard/)

打开浏览器就能看到所有仓库：

* 哪些改了
* 哪些没提交
* 哪些没同步
* 哪些已经落后远端

👉 **轻量、够用、不折腾，特别适合 2H2G 这种小服务器**

---

## 🧠 为什么要做这个？

一个很真实的场景：

你有很多 Git 项目，分散在不同目录：

```text
~/Code
  project-a
  project-b
  project-c
  scripts
```

然后日常就是：

* 😵 忘了哪个 repo 没 push
* 😵 忘了哪个 repo 已经 behind
* 😵 改了一半的代码找不到了
* 😵 每次都要 `cd + git status`

👉 在服务器上更麻烦（没 IDE，更不想开一堆终端）

---

## 💡 这个工具干了什么？

👉 扫描一个目录
👉 找出所有 Git 仓库
👉 用一个网页统一展示 + 操作

你会得到：

* 📊 仓库总览（branch / ahead / behind / dirty）
* 📝 文件改动（staged / unstaged / untracked）
* ⚙️ 常见操作（pull / push / commit / checkout）
* 📸 快照导出 / 导入（保存当前混乱状态）

👉 不用再一个个进目录

---

## 📁 项目结构

```text
git-folder-dashboard/
├── app.py
├── git_service.py
├── snapshot_service.py
├── repo_store.py
└── static/
```

👉 后端干活，前端展示，结构非常简单

---

## 🚀 服务器部署（推荐）

👉 **推荐直接用 release 可执行文件（最省事）**

仓库地址：
👉 [https://github.com/pldz1/git-folder-dashboard](https://github.com/pldz1/git-folder-dashboard)

---

### 📦 下载

```bash
wget https://github.com/pldz1/git-folder-dashboard/releases/download/v1.0.0/git-folder-dashboard-linux-x86_64
```

---

### 🔧 给执行权限

```bash
chmod +x git-folder-dashboard-linux-x86_64
```

---

### ▶️ 运行

```bash
./git-folder-dashboard-linux-x86_64 \
  --host 0.0.0.0 \
  --port 8765 \
  --default-path ~/Code \
  --no-browser=true
```

---

### 🌐 访问

```text
http://<服务器IP>:8765
```

---

## ⚠️ 跑起来之前先确认

### 1️⃣ 防火墙

放行端口：

```text
8765
```

---

### 2️⃣ default-path 很关键

```bash
--default-path /home/xxx/Code
```

👉 这里就是你所有 Git 项目的“根目录”

---

## 🔄 后台运行（推荐）

```bash
nohup ./git-folder-dashboard-linux-x86_64\
  --host 0.0.0.0 \
  --port 8765 \
  --default-path ~/Code \
  --no-browser=true > app.log 2>&1 &
```

看日志：

```bash
tail -f app.log
```

---

## 🛑 停止

```bash
ps -ef | grep git-folder-dashboard
kill <pid>
```

---

## 🔍 常见功能

### 📊 仓库状态

* 当前分支
* ahead / behind
* 是否 dirty
* diverged / clean 状态

---

### 📝 文件操作

* 暂存 / 取消暂存
* 丢弃改动
* 删除 / 忽略文件

---

### ⚙️ 仓库操作

* fetch / pull / push
* commit / checkout

---

### 📸 快照（很实用）

👉 把当前工作区打包成 zip

适合：

* 临时切机器
* 保存未完成状态
* 快速恢复现场

---

## ⚠️ 一些设计说明（很重要）

这个项目是**刻意做轻的**：

* ❌ 不做数据库
* ❌ 不做权限系统
* ❌ 不持久化仓库信息
* ❌ 不替代 IDE

👉 换来的就是：

* ✅ 极低资源占用
* ✅ 启动快
* ✅ 不折腾环境
* ✅ 非常适合小机器

---

## 🧩 适用场景

特别适合：

* 多 Git 仓库开发者
* 云服务器用户
* 2H2G / 低配置环境
* 不想开 IDE 但想看状态的人

---

## 🆚 和 Filebrowser 的搭配

如果你已经在用 Filebrowser：

* 📂 Filebrowser：管文件
* 🔧 Git Folder Dashboard：管 Git

👉 两个一起用，基本就是一个轻量开发环境了

---

## 🔚 总结一句话

> ❌ 以前：一个个仓库进去看
> ✅ 现在：所有仓库状态一屏看完

---

如果你也有：

* 多仓库分散
* 经常忘记同步
* 又不想折腾 IDE

👉 这个工具基本就是为这个场景写的 👍
