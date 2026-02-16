#!/bin/bash
set -euo pipefail

PANEL="/var/www/pterodactyl"
BACKUP_DIR="${PANEL}/_dezz_backups"
PREFIX="backup-unprt-dezz"

TS="$(date -u +%Y-%m-%d-%H-%M-%S)"
OUT="${BACKUP_DIR}/${PREFIX}_${TS}.tar.gz"

mkdir -p "$BACKUP_DIR"
cd "$PANEL"

echo "[0] Put panel into maintenance..."
php artisan down || true

echo "[1] Create backup snapshot..."
# Exclude folder besar / runtime. Ini yang paling aman & cepat.
# Kalau kamu mau FULL backup tanpa exclude apa pun:
#   ganti bagian tar jadi: tar -czf "$OUT" .
tar -czf "$OUT" \
  --exclude="./vendor" \
  --exclude="./node_modules" \
  --exclude="./storage" \
  --exclude="./bootstrap/cache" \
  --exclude="./.git" \
  --exclude="./_dezz_backups" \
  .

echo "[2] Bring panel up..."
php artisan up || true

echo
echo "DONE: Backup created:"
echo "  $OUT"
echo
echo "Cek isi backup:"
echo "  tar -tzf \"$OUT\" | head"
