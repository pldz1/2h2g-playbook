#!/bin/bash

set -e

echo "🛑 Stopping Filebrowser..."

sudo docker compose down

echo "✅ Filebrowser stopped!"
