#!/bin/bash
set -euo pipefail

# ==========================================================
# Pterodactyl FULL UNINSTALL / FULL RESTORE (Anti Protect)
# - Restore SEMUA file dari backup *.bak_TIMESTAMP (latest)
# - Fallback: jika repo git ada, checkout file yang berubah
# ==========================================================

PTERO_ROOT="/var/www/pterodactyl"
ROLLBACK_DIR="${PTERO_ROOT}/.restore_rollback_$(date -u +"%Y-%m-%d-%H-%M-%S")"

# ====== UI ======
NC="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GRN="\033[32m"
YLW="\033[33m"
BLU="\033[34m"
CYN="\033[36m"
DIM="\033[2m"

ok()    { echo -e "${GRN}✅${NC} $*"; }
info()  { echo -e "${CYN}ℹ️${NC}  $*"; }
warn()  { echo -e "${YLW}⚠️${NC}  $*"; }
fail()  { echo -e "${RED}❌${NC} $*"; }
step()  { echo -e "${BLU}➜${NC}  $*"; }
line()  { echo -e "${DIM}------------------------------------------------------------${NC}"; }

on_error() {
  local code=$?
  fail "Terjadi error di baris ${BASH_LINENO[0]} (exit code: $code)"
  echo -e "${DIM}Hint:${NC} jalankan sebagai root/sudo dan pastikan path ${PTERO_ROOT} benar."
  exit "$code"
}
trap on_error ERR

clear 2>/dev/null || true
echo -e "${BOLD}${CYN}🧹 FULL RESTORE Pterodactyl ke Tampilan Awal${NC}"
line
info "Root panel : ${BOLD}${PTERO_ROOT}${NC}"
info "Rollback   : ${BOLD}${ROLLBACK_DIR}${NC}"
line

if [ ! -d "${PTERO_ROOT}" ]; then
  fail "Folder ${PTERO_ROOT} tidak ditemukan."
  exit 1
fi

step "Buat folder rollback (jaga-jaga)..."
mkdir -p "${ROLLBACK_DIR}"
ok "Rollback folder siap."

# ----------------------------------------------------------
# 1) RESTORE SEMUA BACKUP .bak_TIMESTAMP (latest per file)
# ----------------------------------------------------------
step "Scan semua backup *.bak_* lalu restore yang TERBARU untuk setiap file..."
# Cari semua backup
mapfile -t ALL_BAKS < <(find "${PTERO_ROOT}" -type f -name "*.bak_*" 2>/dev/null | sort || true)

if [ "${#ALL_BAKS[@]}" -eq 0 ]; then
  warn "Tidak ada file backup *.bak_* ditemukan di ${PTERO_ROOT}."
else
  ok "Ketemu ${#ALL_BAKS[@]} backup file."

  # Buat daftar unique "file asli" dari backup:
  # contoh: /path/File.php.bak_2026-... -> /path/File.php
  # Kita ambil latest backup per file asli (karena ALL_BAKS sudah sort).
  declare -A LATEST_BY_ORIG=()

  for bak in "${ALL_BAKS[@]}"; do
    orig="${bak%%.bak_*}"         # potong dari .bak_*
    LATEST_BY_ORIG["$orig"]="$bak" # karena iter sort, yang terakhir bakal jadi latest
  done

  restored=0
  for orig in "${!LATEST_BY_ORIG[@]}"; do
    bak="${LATEST_BY_ORIG[$orig]}"

    # simpan file saat ini ke rollback (kalau ada)
    if [ -f "$orig" ]; then
      rb_path="${ROLLBACK_DIR}${orig#${PTERO_ROOT}}"
      mkdir -p "$(dirname "$rb_path")"
      cp -a "$orig" "$rb_path"
    fi

    # restore backup -> file asli
    cp -a "$bak" "$orig"
    chmod 644 "$orig" 2>/dev/null || true
    restored=$((restored + 1))
  done

  ok "Restore dari backup selesai: ${BOLD}${restored}${NC} file dipulihkan dari backup terbaru."
fi

line

# ----------------------------------------------------------
# 2) FALLBACK: kalau ada GIT, balikin file yang berubah
# ----------------------------------------------------------
if [ -d "${PTERO_ROOT}/.git" ]; then
  step "Repo git terdeteksi. Cek file yang berubah untuk dikembalikan..."
  (
    cd "${PTERO_ROOT}"

    # daftar file yang berubah (modified/deleted)
    mapfile -t CHANGED < <(git status --porcelain | awk '{print $2}' | sed 's#^/##' || true)

    if [ "${#CHANGED[@]}" -eq 0 ]; then
      ok "Tidak ada perubahan yang terdeteksi oleh git."
    else
      warn "Git mendeteksi ${#CHANGED[@]} file berubah. Akan dikembalikan (checkout)."

      for f in "${CHANGED[@]}"; do
        # simpan versi sekarang ke rollback (kalau ada)
        if [ -f "${PTERO_ROOT}/${f}" ]; then
          rb_path="${ROLLBACK_DIR}/${f}"
          mkdir -p "$(dirname "$rb_path")"
          cp -a "${PTERO_ROOT}/${f}" "$rb_path"
        fi

        # restore dari git
        git checkout -- "$f" || true
      done

      ok "Git checkout selesai untuk file-file berubah."
    fi
  )
else
  warn "Repo git tidak ditemukan (.git tidak ada). Skip restore via git."
fi

line

# ----------------------------------------------------------
# 3) Bersihin sisa file proteksi yang tidak punya pasangan asli
#    (opsional aman: hanya .bak_ kita BIARIN, karena itu backup)
# ----------------------------------------------------------
step "Validasi cepat..."
info "Rollback tersimpan di: ${BOLD}${ROLLBACK_DIR}${NC}"
ok "Full restore done."

line
echo -e "${BOLD}${GRN}✅ SELESAI! Harusnya tampilan & behavior balik seperti awal.${NC}"
echo -e "${DIM}Catatan:${NC} kalau panel kamu pakai cache/opcache, restart PHP-FPM/nginx/supervisor biar perubahan kebaca."
line

# ----------------------------------------------------------
# OPTIONAL: "NUKIR" RESET TOTAL KE GIT HEAD (SANGAT DESTRUKTIF)
# Default: tidak jalan.
# Kalau kamu bener-bener mau, uncomment bagian bawah.
# ----------------------------------------------------------
: '
step "NUKIR MODE: git reset --hard & bersihkan untracked (DANGEROUS)..."
(
  cd "${PTERO_ROOT}"
  git reset --hard HEAD
  git clean -fd
)
ok "Nukir mode selesai."
'
