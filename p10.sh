#!/bin/bash
set -euo pipefail

PANEL_DIR="/var/www/pterodactyl"
TIMESTAMP_NOW="$(date -u +"%Y-%m-%d-%H-%M-%S")"

ROUTES_FILE="${PANEL_DIR}/routes/admin.php"

CTRL_FILE="${PANEL_DIR}/app/Http/Controllers/Admin/Api/PltaController.php"
MODEL_FILE="${PANEL_DIR}/app/Models/PltaLog.php"
VIEW_DIR="${PANEL_DIR}/resources/views/admin/api/plta"

# marker block yang kita append di routes/admin.php
MARKER_START="/* === PLTA API LOGS (Protect Panel By Dezz) START === */"
MARKER_END="/* === PLTA API LOGS (Protect Panel By Dezz) END === */"

NC="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
RED="\033[31m"; GRN="\033[32m"; YLW="\033[33m"; CYN="\033[36m"

ok()   { echo -e "${GRN}✔${NC} $*"; }
info() { echo -e "${CYN}➜${NC} $*"; }
warn() { echo -e "${YLW}!${NC} $*"; }
fail() { echo -e "${RED}✖${NC} $*"; }

need() { command -v "$1" >/dev/null 2>&1 || { fail "Command tidak ada: $1"; exit 1; }; }
need php
need find
need grep
need sed

if [ ! -d "$PANEL_DIR" ]; then
  fail "Panel dir tidak ditemukan: $PANEL_DIR"
  exit 1
fi

info "UNINSTALL PLTA patch - mulai..."
info "Panel: ${BOLD}${PANEL_DIR}${NC}"

# 1) Restore routes/admin.php dari backup terbaru jika ada
if [ -f "$ROUTES_FILE" ]; then
  latest_routes_bak="$(ls -1t "${ROUTES_FILE}".bak_* 2>/dev/null | head -n 1 || true)"
  if [ -n "${latest_routes_bak}" ] && [ -f "${latest_routes_bak}" ]; then
    info "Restore routes/admin.php dari backup: ${latest_routes_bak}"
    cp -a "$latest_routes_bak" "$ROUTES_FILE"
    ok "routes/admin.php restored"
  else
    # kalau ga ada backup, minimal hapus block marker yang kita tambahin
    if grep -qF "$MARKER_START" "$ROUTES_FILE"; then
      warn "Backup routes tidak ditemukan. Menghapus block PLTA dari routes/admin.php via marker..."
      sed -i.bak_uninstall_"$TIMESTAMP_NOW" "/$(printf '%s' "$MARKER_START" | sed 's/[][\/.^$*]/\\&/g')/,/$(printf '%s' "$MARKER_END" | sed 's/[][\/.^$*]/\\&/g')/d" "$ROUTES_FILE"
      ok "Block PLTA di routes/admin.php dihapus (backup dibuat *.bak_uninstall_*)"
    else
      ok "routes/admin.php: tidak ada patch PLTA"
    fi
  fi
else
  warn "routes/admin.php tidak ada (aneh). Skip."
fi

# 2) Restore sidebar file dari backup jika ada
# Kita cari semua file view yang punya backup .bak_TIMESTAMP dan mengandung route admin.api.plta.index
info "Mencari modifikasi sidebar yang mengandung admin.api.plta.index ..."
sidebar_candidates="$(grep -RIl "admin\.api\.plta\.index" "${PANEL_DIR}/resources/views" 2>/dev/null || true)"
if [ -n "${sidebar_candidates}" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    latest_bak="$(ls -1t "${f}".bak_* 2>/dev/null | head -n 1 || true)"
    if [ -n "$latest_bak" ] && [ -f "$latest_bak" ]; then
      info "Restore sidebar file: $f dari backup: $latest_bak"
      cp -a "$latest_bak" "$f"
      ok "Restored: $f"
    else
      # kalau ga ada backup, coba hapus blok li yang kita sisipkan (best-effort)
      warn "Backup tidak ada untuk $f. Hapus item menu PLTA (best-effort)."
      sed -i.bak_uninstall_"$TIMESTAMP_NOW" '/route('\''admin\.api\.plta\.index'\''/,+5d' "$f" || true
      ok "Removed PLTA menu line(s) from $f (backup dibuat *.bak_uninstall_*)"
    fi
  done <<< "$sidebar_candidates"
else
  ok "Tidak ada file sidebar yang mengandung admin.api.plta.index"
fi

# 3) Hapus file controller/model/views yang dibuat
if [ -f "$CTRL_FILE" ]; then
  info "Hapus controller: $CTRL_FILE"
  rm -f "$CTRL_FILE"
  ok "Controller dihapus"
else
  ok "Controller tidak ada (skip)"
fi

if [ -f "$MODEL_FILE" ]; then
  info "Hapus model: $MODEL_FILE"
  rm -f "$MODEL_FILE"
  ok "Model dihapus"
else
  ok "Model tidak ada (skip)"
fi

if [ -d "$VIEW_DIR" ]; then
  info "Hapus views folder: $VIEW_DIR"
  rm -rf "$VIEW_DIR"
  ok "Views dihapus"
else
  ok "Views folder tidak ada (skip)"
fi

# 4) Hapus migration yang kita buat (yang namanya create_plta_logs_table)
info "Cari migration create_plta_logs_table..."
migs="$(find "${PANEL_DIR}/database/migrations" -maxdepth 1 -type f -name "*_create_plta_logs_table.php" 2>/dev/null || true)"
if [ -n "$migs" ]; then
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    info "Hapus migration: $m"
    rm -f "$m"
    ok "Migration dihapus: $m"
  done <<< "$migs"
else
  ok "Migration PLTA tidak ada"
fi

# 5) Drop table plta_logs (opsional tapi biar bersih total)
# Ini aman walau table ga ada.
info "Drop table plta_logs (jika ada)..."
php -r '
$path = __DIR__ . "/var/www/pterodactyl/bootstrap/app.php";
if (!file_exists($path)) { fwrite(STDERR, "bootstrap/app.php not found\n"); exit(0); }
$app = require $path;
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();
try {
  if (Illuminate\Support\Facades\Schema::hasTable("plta_logs")) {
    Illuminate\Support\Facades\Schema::drop("plta_logs");
    echo "Dropped table plta_logs\n";
  } else {
    echo "Table plta_logs not found\n";
  }
} catch (Throwable $e) {
  echo "Skip drop (error): " . $e->getMessage() . "\n";
}
' || true
ok "Table cleanup done"

# 6) Clear caches biar admin page balik normal
info "Clear cache..."
cd "$PANEL_DIR"
php artisan route:clear || true
php artisan view:clear || true
php artisan config:clear || true
php artisan cache:clear || true
ok "Cache cleared"

echo
ok "UNINSTALL selesai. Panel harus balik normal 100%."
echo -e "${DIM}Kalau masih error, kirim output: tail -n 120 storage/logs/laravel-*.log${NC}"
