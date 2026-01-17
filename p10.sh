#!/bin/bash
set -euo pipefail

PANEL="/var/www/pterodactyl"
cd "$PANEL"

php artisan down || true

echo "[1] Hapus module PLTA yang dibuat..."
rm -f app/Http/Controllers/Admin/Api/PltaController.php || true
rm -f app/Models/PltaLog.php || true
rm -rf resources/views/admin/api/plta || true
rm -f database/migrations/*_create_plta_logs_table.php || true

echo "[2] Hapus block routes yang ditambah (marker Protect Panel)..."
ROUTES="routes/admin.php"
if [ -f "$ROUTES" ]; then
  cp -a "$ROUTES" "${ROUTES}.pre_factoryfix_$(date -u +%Y-%m-%d-%H-%M-%S)"

  # hapus semua block marker Protect Panel (apa pun variannya)
  perl -0777 -i -pe '
    s#/\\*\\s*===.*?Protect Panel By Dezz.*?START\\s*===\\s*\\*/.*?/\\*\\s*===.*?Protect Panel By Dezz.*?END\\s*===\\s*\\*/\\s*##gs
  ' "$ROUTES"
fi

echo "[3] Restore semua file dari backup .bak_* paling awal..."
# ambil semua backup
mapfile -t BAKS < <(find "$PANEL" -type f \( -name "*.bak_*" -o -name "*.bak_uninstall_*" \) 2>/dev/null | sort)

if [ "${#BAKS[@]}" -eq 0 ]; then
  echo "Tidak ada file backup .bak_* ditemukan."
else
  # pilih backup paling awal per file original
  declare -A PICK_TS
  declare -A PICK_FILE

  for b in "${BAKS[@]}"; do
    orig="$b"
    orig="${orig%.bak_uninstall_*}"
    orig="${orig%.bak_*}"

    # timestamp string (buat sorting kasar)
    ts="9999-99-99-99-99-99"
    if [[ "$b" =~ \.bak_uninstall_([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2})$ ]]; then
      ts="${BASH_REMATCH[1]}"
    elif [[ "$b" =~ \.bak_([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2})$ ]]; then
      ts="${BASH_REMATCH[1]}"
    fi

    # ambil yang paling awal (lexicographically kecil)
    if [ -z "${PICK_TS[$orig]+x}" ] || [[ "$ts" < "${PICK_TS[$orig]}" ]]; then
      PICK_TS["$orig"]="$ts"
      PICK_FILE["$orig"]="$b"
    fi
  done

  for orig in "${!PICK_FILE[@]}"; do
    b="${PICK_FILE[$orig]}"
    # pastikan folder ada
    mkdir -p "$(dirname "$orig")"
    cp -a "$b" "$orig"
    echo "RESTORED: $orig  <=  $b"
  done
fi

echo "[4] Clear cache Laravel..."
php artisan optimize:clear || true
php artisan view:clear || true
php artisan route:clear || true
php artisan config:clear || true
php artisan cache:clear || true

php artisan up || true

echo
echo "DONE: Factory rollback selesai."
echo "Kalau masih error, cek log:"
echo "  tail -n 200 storage/logs/laravel-*.log"
