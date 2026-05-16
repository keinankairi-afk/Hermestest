#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="/opt/hermes-agent"
PM2_NAME="hermes-agent"
ROUTER_PM2_NAME="9router"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

echo "HERMES AI AGENT UNINSTALLER"
echo "Ini akan menghentikan PM2 process dan menghapus folder: $APP_DIR"
read -r -p "Lanjut? [y/N]: " confirm
confirm="${confirm:-N}"

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Dibatalkan."
  exit 0
fi

if command -v pm2 >/dev/null 2>&1; then
  pm2 delete "$PM2_NAME" >/dev/null 2>&1 || true

  read -r -p "Hapus juga 9Router PM2 process? [y/N]: " remove_router
  remove_router="${remove_router:-N}"
  if [[ "$remove_router" =~ ^[Yy]$ ]]; then
    pm2 delete "$ROUTER_PM2_NAME" >/dev/null 2>&1 || true
  fi

  pm2 save || true
fi

read -r -p "Backup folder sebelum hapus? [Y/n]: " backup
backup="${backup:-Y}"

if [[ -d "$APP_DIR" ]]; then
  if [[ "$backup" =~ ^[Yy]$ ]]; then
    BACKUP="${APP_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    as_root mv "$APP_DIR" "$BACKUP"
    echo -e "${GREEN}Folder dibackup ke $BACKUP${NC}"
  else
    as_root rm -rf "$APP_DIR"
    echo -e "${GREEN}Folder dihapus.${NC}"
  fi
fi

echo -e "${GREEN}Uninstall selesai.${NC}"
