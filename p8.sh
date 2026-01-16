#!/bin/bash
set -euo pipefail

PTERO="/var/www/pterodactyl"

KERNEL="${PTERO}/app/Http/Kernel.php"
ROUTES="${PTERO}/routes/api-client.php"
MW_DIR="${PTERO}/app/Http/Middleware/ProtectPanelByDezz"
MW_FILE="${MW_DIR}/OwnerOnlyServerAccess.php"

restore_latest_backup () {
  local target="$1"
  local latest
  latest="$(ls -1t "${target}.bak_"* 2>/dev/null | head -n 1 || true)"
  if [ -n "${latest}" ]; then
    echo "↩️ Restore: ${target}"
    mv -f "$latest" "$target"
    echo "✅ OK: $(basename "$target") restored"
  else
    echo "⚠️ Backup tidak ditemukan untuk: ${target}"
  fi
}

echo "🧯 EMERGENCY ROLLBACK (HTTP 500 FIX)"
echo "-----------------------------------"

restore_latest_backup "$KERNEL"
restore_latest_backup "$ROUTES"
restore_latest_backup "$MW_FILE"

# Kalau middleware file gak ada backup, hapus file + foldernya biar aman
if [ -f "$MW_FILE" ]; then
  echo "🧹 Hapus middleware custom biar aman..."
  rm -f "$MW_FILE" || true
fi
if [ -d "$MW_DIR" ]; then
  rmdir "$MW_DIR" 2>/dev/null || true
fi

echo "🧹 Clear cache..."
cd "$PTERO"
php artisan optimize:clear || true
php artisan config:clear || true
php artisan route:clear || true
php artisan view:clear || true
php artisan cache:clear || true

echo "✅ DONE. Coba buka panel lagi."
