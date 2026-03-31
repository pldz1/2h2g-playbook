#!/bin/bash

set -e

echo "🚀 Starting Filebrowser..."

# 确保目录存在
mkdir -p database config

# 启动容器（后台）
sudo docker compose up -d

echo "✅ Filebrowser started!"
echo "👉 访问地址: http://localhost:10060"
