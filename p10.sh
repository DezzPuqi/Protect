#!/bin/bash
set -euo pipefail

PANEL_DIR="/var/www/pterodactyl"
cd "$PANEL_DIR"

echo "[*] Restoring PLTA patches (routes/sidebar/controller/views/model/migration) ..."

restore_latest_backup() {
  local target="$1"
  local latest
  latest="$(ls -1t "${target}.bak_"* 2>/dev/null | head -n 1 || true)"
  if [ -n "$latest" ]; then
    cp -a "$latest" "$target"
    echo "[OK] Restored: $target  <=  $(basename "$latest")"
  else
    echo "[SKIP] No backup for: $target"
  fi
}

remove_if_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    rm -f "$f"
    echo "[OK] Removed: $f"
  fi
}

# 1) Restore routes/admin.php (paling sering penyebab 500 kalau kepatch salah)
restore_latest_backup "$PANEL_DIR/routes/admin.php"

# 2) Restore sidebar yang kepatch (auto: semua file view yg punya backup dan mengandung admin.api.plta)
echo "[*] Restoring any sidebar/view backups containing 'admin.api.plta' ..."
while IFS= read -r bak; do
  orig="${bak%.bak_*}"
  # restore only if original exists and backup exists
  if [ -f "$orig" ]; then
    cp -a "$bak" "$orig"
    echo "[OK] Restored view: $orig <= $(basename "$bak")"
  fi
done < <(grep -RIl "admin\.api\.plta" "$PANEL_DIR/resources/views" 2>/dev/null | while read -r f; do ls -1t "${f}.bak_"* 2>/dev/null | head -n 1 || true; done)

# 3) Restore specific PLTA files if backups exist
restore_latest_backup "$PANEL_DIR/app/Http/Controllers/Admin/Api/PltaController.php"
restore_latest_backup "$PANEL_DIR/app/Models/PltaLog.php"
restore_latest_backup "$PANEL_DIR/resources/views/admin/api/plta/index.blade.php"
restore_latest_backup "$PANEL_DIR/resources/views/admin/api/plta/logs.blade.php"

# 4) Kalau file-file PLTA tidak punya backup (berarti sebelumnya memang tidak ada), hapus saja
remove_if_exists "$PANEL_DIR/app/Http/Controllers/Admin/Api/PltaController.php"
remove_if_exists "$PANEL_DIR/app/Models/PltaLog.php"
remove_if_exists "$PANEL_DIR/resources/views/admin/api/plta/index.blade.php"
remove_if_exists "$PANEL_DIR/resources/views/admin/api/plta/logs.blade.php"

# 5) Hapus migration PLTA yang kebikin (biar bersih)
echo "[*] Removing PLTA migration files ..."
find "$PANEL_DIR/database/migrations" -maxdepth 1 -type f -name "*_create_plta_logs_table.php" -print -delete || true

# 6) Bersihin cache Laravel (wajib biar admin balik normal)
echo "[*] Clearing caches ..."
php artisan route:clear || true
php artisan view:clear || true
php artisan config:clear || true
php artisan cache:clear || true

echo "[DONE] Restore selesai. Coba buka admin panel lagi."
echo "Note: kalau migration sempat jalan, tabel 'plta_logs' mungkin masih ada (tidak bikin error)."
