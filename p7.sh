#!/bin/bash
set -euo pipefail

# ==========================================================
# Protect Panel By Dezz - FULL FIX (Owner-Only Server Access)
# Tujuan:
# - BLOCK dari AWAL pas orang buka server orang lain
# - Jadi console/websocket/files/settings/dll ikut keblok
# - Log ke Activity: "User <username> baru saja mencoba mengakses server mu."
#
# Rule:
# - Admin ID 1: bebas
# - Selain itu: HARUS owner server (owner_id == user_id)
# ==========================================================

PTERO_BASE="/var/www/pterodactyl"

MIDDLEWARE_DIR="${PTERO_BASE}/app/Http/Middleware/ProtectPanelByDezz"
MIDDLEWARE_PATH="${MIDDLEWARE_DIR}/OwnerOnlyServerAccess.php"

KERNEL_PATH="${PTERO_BASE}/app/Http/Kernel.php"
ROUTES_PATH="${PTERO_BASE}/routes/api-client.php"

TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"

# =========================
# UI - Protect Panel By Dezz (serem + html vibe)
# =========================
NC="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
RED="\033[31m"; GRN="\033[32m"; YLW="\033[33m"; BLU="\033[34m"; CYN="\033[36m"; WHT="\033[37m"

hr() { echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

banner() {
  clear 2>/dev/null || true
  echo -e "${RED}${BOLD}<html>${NC}"
  echo -e "${RED}${BOLD}  <head>${NC}"
  echo -e "${RED}${BOLD}    <title>PROTECT PANEL</title>${NC}"
  echo -e "${RED}${BOLD}  </head>${NC}"
  echo -e "${RED}${BOLD}  <body>${NC}"
  echo -e "${RED}${BOLD}    <h1>🩸 SERVER SHIELD: OWNER-ONLY LOCKDOWN</h1>${NC}"
  echo -e "${WHT}${BOLD}    <p>WM: Protect Panel By Dezz</p>${NC}"
  echo -e "${RED}${BOLD}  </body>${NC}"
  echo -e "${RED}${BOLD}</html>${NC}"
  hr
}

ok()   { echo -e "${GRN}✔${NC} $*"; }
info() { echo -e "${CYN}➜${NC} $*"; }
warn() { echo -e "${YLW}!${NC} $*"; }
fail() { echo -e "${RED}✖${NC} $*"; }

spin() {
  local msg="$1"; shift
  local pid
  local s='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  echo -ne "${BLU}${BOLD}${msg}${NC} ${DIM}${s:0:1}${NC}"
  ("$@") >/dev/null 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i + 1) % 10 ))
    echo -ne "\r${BLU}${BOLD}${msg}${NC} ${DIM}${s:$i:1}${NC}"
    sleep 0.08
  done
  wait "$pid"
  echo -ne "\r${BLU}${BOLD}${msg}${NC} ${GRN}DONE${NC}\n"
}

on_error() {
  local code=$?
  echo
  fail "Installer gagal (exit code: $code)"
  echo -e "${DIM}Cek permission & pastiin path Pterodactyl bener: ${PTERO_BASE}${NC}"
  exit "$code"
}
trap on_error ERR

backup_if_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    mv "$f" "${f}.bak_${TIMESTAMP}"
    ok "Backup: ${DIM}${f}.bak_${TIMESTAMP}${NC}"
  else
    warn "Skip backup (file tidak ada): $(basename "$f")"
  fi
}

patch_kernel_alias() {
  # add alias ppbd.owner to Kernel.php, support both $middlewareAliases and $routeMiddleware
  local tmp
  tmp="$(mktemp)"

  if grep -q "ppbd\.owner" "$KERNEL_PATH"; then
    warn "Kernel: alias ppbd.owner sudah ada, skip."
    rm -f "$tmp"
    return 0
  fi

  # Laravel newer: protected $middlewareAliases = [
  if grep -q "protected \\$middlewareAliases" "$KERNEL_PATH"; then
    awk '
      BEGIN{done=0}
      {
        print $0
        if (!done && $0 ~ /protected \$middlewareAliases[[:space:]]*=[[:space:]]*\[/) {
          print "        \x27ppbd.owner\x27 => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\ProtectPanelByDezz\\\\OwnerOnlyServerAccess::class,"
          done=1
        }
      }
    ' "$KERNEL_PATH" > "$tmp"
    mv "$tmp" "$KERNEL_PATH"
    ok "Kernel: alias ditambah ke \$middlewareAliases"
    return 0
  fi

  # Laravel older: protected $routeMiddleware = [
  if grep -q "protected \\$routeMiddleware" "$KERNEL_PATH"; then
    awk '
      BEGIN{done=0}
      {
        print $0
        if (!done && $0 ~ /protected \$routeMiddleware[[:space:]]*=[[:space:]]*\[/) {
          print "        \x27ppbd.owner\x27 => \\\\Pterodactyl\\\\Http\\\\Middleware\\\\ProtectPanelByDezz\\\\OwnerOnlyServerAccess::class,"
          done=1
        }
      }
    ' "$KERNEL_PATH" > "$tmp"
    mv "$tmp" "$KERNEL_PATH"
    ok "Kernel: alias ditambah ke \$routeMiddleware"
    return 0
  fi

  rm -f "$tmp"
  warn "Kernel: gak nemu \$middlewareAliases / \$routeMiddleware. Alias belum kepasang otomatis."
  warn "Lu harus masukin manual alias middleware ke Kernel.php: ppbd.owner => OwnerOnlyServerAccess::class"
  return 0
}

patch_routes_group() {
  # Apply middleware to servers/{server} group in routes/api-client.php
  # We try to inject middleware key into the array config for that group.
  local tmp
  tmp="$(mktemp)"

  if [ ! -f "$ROUTES_PATH" ]; then
    warn "Routes: file tidak ada: $ROUTES_PATH"
    rm -f "$tmp"
    return 0
  fi

  if grep -q "ppbd\.owner" "$ROUTES_PATH"; then
    warn "Routes: ppbd.owner sudah dipasang, skip."
    rm -f "$tmp"
    return 0
  fi

  # This tries to find the group line containing servers/{server} and inject middleware.
  # Works for common patterns:
  # Route::group(['prefix' => 'servers/{server}', ...], function () {
  awk '
    BEGIN{injected=0}
    {
      if (!injected && $0 ~ /servers\/\{server\}/ && $0 ~ /Route::group\(\[/) {
        print $0
        injected=1
        next
      }

      if (injected==1) {
        # We are right after the Route::group([ line; inject middleware only if not present soon.
        print "    \x27middleware\x27 => [\x27ppbd.owner\x27],"
        injected=2
      }

      print $0
    }
  ' "$ROUTES_PATH" > "$tmp"

  if grep -q "middleware.*ppbd\.owner" "$tmp"; then
    mv "$tmp" "$ROUTES_PATH"
    ok "Routes: middleware ppbd.owner dipasang ke group servers/{server}"
  else
    rm -f "$tmp"
    warn "Routes: gagal auto-inject (pattern beda)."
    warn "Lu bisa pasang manual di routes/api-client.php pada group servers/{server}: middleware => [\x27ppbd.owner\x27]"
  fi
}

# =========================
# RUN
# =========================
banner
info "Mode     : Installer"
info "Time UTC : ${BOLD}${TIMESTAMP}${NC}"
info "Base     : ${BOLD}${PTERO_BASE}${NC}"
hr
info "Target 1 : ${BOLD}${MIDDLEWARE_PATH}${NC}"
info "Target 2 : ${BOLD}${KERNEL_PATH}${NC}"
info "Target 3 : ${BOLD}${ROUTES_PATH}${NC}"
hr

# backups
info "Backup penting..."
backup_if_exists "$MIDDLEWARE_PATH"
backup_if_exists "$KERNEL_PATH"
backup_if_exists "$ROUTES_PATH"
hr

# create middleware
spin "Membuat folder middleware..." mkdir -p "$MIDDLEWARE_DIR"
chmod 755 "$MIDDLEWARE_DIR"

info "Menulis middleware: OwnerOnlyServerAccess (log activity + block total)..."
cat > "$MIDDLEWARE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Middleware\ProtectPanelByDezz;

use Closure;
use Illuminate\Http\Request;
use Pterodactyl\Models\Server;
use Pterodactyl\Facades\Activity;

class OwnerOnlyServerAccess
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();

        // Harus login
        if (!$user) {
            return response()->json([
                'object' => 'error',
                'attributes' => [
                    'status' => 401,
                    'message' => 'Unauthorized.',
                ],
            ], 401);
        }

        // Admin ID 1 bebas akses semua
        if ((int) $user->id === 1) {
            return $next($request);
        }

        // Ambil server dari route model binding
        $server = $request->route('server');

        // Kadang parameter bisa string uuid/short uuid, tapi biasanya model Server sudah kebind.
        if (!$server instanceof Server) {
            // Kalau gak kebaca server-nya, jangan ngasih celah.
            return response()->json([
                'object' => 'error',
                'attributes' => [
                    'status' => 403,
                    'message' => 'Access denied.',
                ],
            ], 403);
        }

        $ownerId = $server->owner_id
            ?? $server->user_id
            ?? ($server->owner?->id ?? null)
            ?? ($server->user?->id ?? null);

        // Kalau owner gak jelas, block
        if ($ownerId === null) {
            $this->logAttempt($request, $server, $user, 'Owner not detected');
            return $this->deny();
        }

        // Owner-only: kalau bukan owner => BLOCK TOTAL + LOG
        if ((int) $ownerId !== (int) $user->id) {
            $this->logAttempt($request, $server, $user, 'Foreign server access blocked');
            return $this->deny();
        }

        return $next($request);
    }

    private function deny()
    {
        return response()->json([
            'object' => 'error',
            'attributes' => [
                'status' => 403,
                'message' => '⛔ Access denied (Protect Panel By Dezz).',
            ],
        ], 403);
    }

    private function logAttempt(Request $request, Server $server, $user, string $reason): void
    {
        $username = $user->username
            ?? trim(($user->first_name ?? '') . ' ' . ($user->last_name ?? ''))
            ?? $user->email
            ?? ('User#' . ($user->id ?? 'Unknown'));

        $path = $request->path();
        $ip = method_exists($request, 'ip') ? $request->ip() : null;

        Activity::event('server:shield.blocked')
            ->subject($server)
            ->property('attempted_by_id', $user->id ?? null)
            ->property('attempted_by', $username)
            ->property('ip', $ip)
            ->property('path', $path)
            ->property('reason', $reason)
            ->log(sprintf('User %s baru saja mencoba mengakses server mu.', $username));
    }
}
EOF

chmod 644 "$MIDDLEWARE_PATH"
ok "Middleware dibuat: ${BOLD}${MIDDLEWARE_PATH}${NC}"
hr

# patch kernel
info "Patch Kernel (register alias middleware)..."
patch_kernel_alias
hr

# patch routes
info "Patch routes/api-client.php (apply middleware ke servers/{server} group)..."
patch_routes_group
hr

ok "✅ FULL FIX selesai dipasang!"
info "Efek: begitu ada yang coba buka server orang lain → langsung keblok dari awal (termasuk console/files/websocket/settings)."
info "Log : Activity server akan muncul: ${BOLD}User <username> baru saja mencoba mengakses server mu.${NC}"
echo -e "${WHT}${BOLD}WM:${NC} ${CYN}Protect Panel By Dezz${NC}"
hr
echo -e "${YLW}!${NC} Kalau panel lu cache route/config, restart layanan yg biasa lu pake (nggak gue paksa dari script)."
