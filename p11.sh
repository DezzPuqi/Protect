#!/bin/bash
set -euo pipefail

PANEL="/var/www/pterodactyl"
BACKUP_DIR="${PANEL}/_dezz_backups"
PREFIX="backup-unprt-dezz"

# kamu bisa jalankan:
#   ./restore-unprt-dezz.sh /path/ke/backup.tar.gz
# atau tanpa argumen, dia auto pilih backup TERBARU
IN="${1:-}"

cd "$PANEL"

choose_latest_backup () {
  ls -1 "${BACKUP_DIR}/${PREFIX}_"*.tar.gz 2>/dev/null | sort | tail -n 1 || true
}

if [ -z "$IN" ]; then
  IN="$(choose_latest_backup)"
fi

if [ -z "$IN" ] || [ ! -f "$IN" ]; then
  echo "ERROR: Backup tidak ditemukan."
  echo "Taruh backup di:"
  echo "  $BACKUP_DIR"
  echo "Atau panggil dengan path:"
  echo "  $0 /full/path/backup-unprt-dezz_YYYY-mm-dd-HH-MM-SS.tar.gz"
  exit 1
fi

echo "[0] Put panel into maintenance..."
php artisan down || true

echo "[1] Restore from backup:"
echo "  $IN"

# Safety: bikin snapshot current state (opsional tapi recommended)
TS="$(date -u +%Y-%m-%d-%H-%M-%S)"
SAFETY="${BACKUP_DIR}/before-restore_${TS}.tar.gz"

echo "[1.1] Safety snapshot current state (optional)..."
tar -czf "$SAFETY" \
  --exclude="./vendor" \
  --exclude="./node_modules" \
  --exclude="./storage" \
  --exclude="./bootstrap/cache" \
  --exclude="./.git" \
  --exclude="./_dezz_backups" \
  .

echo "  Safety saved: $SAFETY"

echo "[2] Extract backup over panel directory..."
# Extract langsung ke folder panel, overwrite file yang ada
tar -xzf "$IN" -C "$PANEL"

echo "[3] Clear cache Laravel..."
php artisan optimize:clear || true
php artisan view:clear || true
php artisan route:clear || true
php artisan config:clear || true
php artisan cache:clear || true

echo "[4] Bring panel up..."
php artisan up || true

echo
echo "DONE: Restore selesai. Panel kembali seperti di backup."
echo "Kalau ada error, cek log:"
echo "  tail -n 200 storage/logs/laravel-*.log"
