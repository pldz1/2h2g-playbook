#!/bin/bash

set -e

echo "⚠️  This will DELETE all data (database & config)"
read -p "Are you sure? (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "❌ Cancelled"
  exit 1
fi

echo "🧹 Cleaning Filebrowser..."

# 停止并删除容器 + 网络
sudo docker compose down -v

# 删除本地数据
rm -rf database/*
rm -rf config/*

echo "✅ Clean complete!"
