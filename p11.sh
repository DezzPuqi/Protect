#!/bin/bash

TARGET_FILE="/var/www/pterodactyl/resources/views/templates/base/core.blade.php"

echo "🔎 Cari backup terbaru untuk $TARGET_FILE ..."

LATEST_BACKUP="$(ls -1t ${TARGET_FILE}.bak_* 2>/dev/null | head -n 1)"

if [ -z "$LATEST_BACKUP" ]; then
  echo "❌ Backup tidak ditemukan (format: ${TARGET_FILE}.bak_*)"
  echo "➡️  Kalau kamu punya isi file original, kirim sini nanti aku bikinin restore manual."
  exit 1
fi

cp "$LATEST_BACKUP" "$TARGET_FILE"
echo "✅ Berhasil restore dari backup: $LATEST_BACKUP"
