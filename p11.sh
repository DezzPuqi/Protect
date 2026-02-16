#!/bin/bash
set -euo pipefail

PANEL="/var/www/pterodactyl"
cd "$PANEL"

php artisan down || true

TS="$(date -u +%Y-%m-%d-%H-%M-%S)"

echo "[1] Hapus middleware PLTA protect..."
rm -f app/Http/Middleware/PltaIdOneOnly.php || true

echo "[2] Hapus alias middleware 'plta.id1' dari Kernel.php..."
KERNEL="app/Http/Kernel.php"
if [ -f "$KERNEL" ]; then
  cp -a "$KERNEL" "${KERNEL}.pre_unprotect_${TS}"

  # hapus baris alias routeMiddleware
  perl -0777 -i -pe '
    s/\s*\x27plta\.id1\x27\s*=>\s*\\App\\Http\\Middleware\\PltaIdOneOnly::class,\s*\n//gs
  ' "$KERNEL" || true

  # kalau ada fallback block yang pernah ketambah (routeMiddlewarePltaProtect), hapus juga
  perl -0777 -i -pe '
    s/\n\s*\/\/ Protect PLTA\s*\n\s*protected\s+\$routeMiddlewarePltaProtect\s*=\s*\[\s*\n\s*\x27plta\.id1\x27\s*=>\s*\\App\\Http\\Middleware\\PltaIdOneOnly::class,\s*\n\s*\];\s*//gs
  ' "$KERNEL" || true
fi

echo "[3] Balikin semua file dari backup .bak_protect_* paling awal..."
# ambil semua backup protect
mapfile -t BAKS < <(find "$PANEL" -type f -name "*.bak_protect_*" 2>/dev/null | sort)

if [ "${#BAKS[@]}" -eq 0 ]; then
  echo "Tidak ada file backup .bak_protect_* ditemukan."
else
  declare -A PICK_TS
  declare -A PICK_FILE

  for b in "${BAKS[@]}"; do
    orig="$b"
    orig="${orig%.bak_protect_*}"

    ts="9999-99-99-99-99-99"
    if [[ "$b" =~ \.bak_protect_([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2})$ ]]; then
      ts="${BASH_REMATCH[1]}"
    fi

    if [ -z "${PICK_TS[$orig]+x}" ] || [[ "$ts" < "${PICK_TS[$orig]}" ]]; then
      PICK_TS["$orig"]="$ts"
      PICK_FILE["$orig"]="$b"
    fi
  done

  for orig in "${!PICK_FILE[@]}"; do
    b="${PICK_FILE[$orig]}"
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
echo "DONE: PLTA protect rollback selesai."
echo "Kalau masih error, cek log:"
echo "  tail -n 200 storage/logs/laravel-*.log"
