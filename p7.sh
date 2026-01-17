#!/bin/bash
set -euo pipefail

# ==========================================================
# Protect Panel By Dezz — OWNER-ONLY LOCK (ALL SERVER FEATURES)
# ✅ TANPA PATCH KERNEL / TANPA PATCH ROUTES (biar gak 500)
#
# Cara kerja:
# - Bikin middleware: OwnerOnlyServerAccess
# - Middleware ini ngecek SEMUA request yang punya route param {server}
#   => kalau bukan owner (kecuali Admin ID 1) LANGSUNG BLOCK di AWAL
#   => console / files / power / schedules / backups / settings / db / dll IKUT KEKUNCI
# - Log ke Activity server target:
#   "User <username> baru saja mencoba mengakses server mu."
#
# Bonus:
# - Kalau request accept HTML => tampil halaman HTML serem + WM.
# ==========================================================

PTERO_BASE="/var/www/pterodactyl"
TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"

MIDDLEWARE_DIR="${PTERO_BASE}/app/Http/Middleware/ProtectPanelByDezz"
MIDDLEWARE_FILE="${MIDDLEWARE_DIR}/OwnerOnlyServerAccess.php"

CLIENT_API_CTRL="${PTERO_BASE}/app/Http/Controllers/Api/Client/ClientApiController.php"

# (optional) kalau kemarin sempet 500 karena kernel/routes kepatch, kita restore backup terakhir kalau ada
KERNEL_PATH="${PTERO_BASE}/app/Http/Kernel.php"
ROUTES_PATH="${PTERO_BASE}/routes/api-client.php"

# =========================
# UI - Protect Panel By Dezz
# =========================
NC="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
RED="\033[31m"; GRN="\033[32m"; YLW="\033[33m"; BLU="\033[34m"; CYN="\033[36m"; WHT="\033[37m"

hr() { echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

banner() {
  clear 2>/dev/null || true
  echo -e "${RED}${BOLD}<html>${NC}"
  echo -e "${RED}${BOLD}  <head><title>PROTECT PANEL</title></head>${NC}"
  echo -e "${RED}${BOLD}  <body>${NC}"
  echo -e "${RED}${BOLD}    <h1>🩸 OWNER-ONLY SERVER SHIELD (ALL FEATURES LOCKED)</h1>${NC}"
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
  echo -e "${DIM}Cek permission + path: ${PTERO_BASE}${NC}"
  exit "$code"
}
trap on_error ERR

backup_if_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    mv "$f" "${f}.bak_${TIMESTAMP}"
    ok "Backup: ${DIM}${f}.bak_${TIMESTAMP}${NC}"
  else
    warn "File tidak ada: $(basename "$f")"
  fi
}

restore_latest() {
  local f="$1"
  local latest
  latest="$(ls -1t "${f}.bak_"* 2>/dev/null | head -n 1 || true)"
  if [ -n "${latest}" ] && [ -f "${latest}" ]; then
    mv "$latest" "$f"
    ok "Restore: ${DIM}${f}${NC} (dari $(basename "$latest"))"
  else
    warn "Restore skip (backup gak ketemu): $(basename "$f")"
  fi
}

patch_client_api_controller() {
  # Inject middleware call into ClientApiController constructor without rewriting whole file.
  # Insert line after first "{" of __construct.
  local f="$CLIENT_API_CTRL"
  local tmp
  tmp="$(mktemp)"

  if [ ! -f "$f" ]; then
    fail "ClientApiController tidak ditemukan: $f"
    exit 1
  fi

  if grep -q "OwnerOnlyServerAccess::class" "$f" || grep -q "ProtectPanelByDezz\\\\OwnerOnlyServerAccess" "$f"; then
    warn "ClientApiController sudah dipatch, skip."
    rm -f "$tmp"
    return 0
  fi

  awk '
    BEGIN { inctor=0; injected=0 }
    {
      line=$0
      if (injected==0 && inctor==0 && line ~ /function __construct[[:space:]]*\(/) {
        inctor=1
        print line
        next
      }

      if (injected==0 && inctor==1) {
        # wait for the first opening brace of constructor
        print line
        if (line ~ /\{[[:space:]]*$/) {
          print "        // 🔒 Protect Panel By Dezz: lock ALL {server} access (owner-only, admin id 1 bypass)"
          print "        $this->middleware(\\\\Pterodactyl\\\\Http\\\\Middleware\\\\ProtectPanelByDezz\\\\OwnerOnlyServerAccess::class);"
          injected=1
          inctor=0
        }
        next
      }

      print line
    }
  ' "$f" > "$tmp"

  mv "$tmp" "$f"
  ok "Patch: middleware dipasang ke ClientApiController (tanpa Kernel/routes)."
}

banner
info "Base     : ${BOLD}${PTERO_BASE}${NC}"
info "Time UTC : ${BOLD}${TIMESTAMP}${NC}"
hr
info "Target 1 : ${BOLD}${MIDDLEWARE_FILE}${NC}"
info "Target 2 : ${BOLD}${CLIENT_API_CTRL}${NC}"
hr

# OPTIONAL: restore kernel/routes kalau sebelumnya kepatch dan bikin 500
info "Optional fix 500: restore Kernel/routes dari backup terakhir (kalau ada)..."
restore_latest "$KERNEL_PATH"
restore_latest "$ROUTES_PATH"
hr

# Backup target utama
info "Backup file target..."
backup_if_exists "$MIDDLEWARE_FILE"
backup_if_exists "$CLIENT_API_CTRL"
hr

spin "Menyiapkan folder middleware..." mkdir -p "$MIDDLEWARE_DIR"
chmod 755 "$MIDDLEWARE_DIR"

info "Menulis middleware OwnerOnlyServerAccess (ALL SERVER FEATURES LOCK)..."
cat > "$MIDDLEWARE_FILE" <<'EOF'
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
        // Hanya enforce kalau route punya parameter "server"
        $serverParam = $request->route('server');

        // Route tanpa {server} => biarin lewat
        if ($serverParam === null) {
            return $next($request);
        }

        $user = $request->user();

        if (!$user) {
            return $this->deny($request, null, 'Unauthorized.');
        }

        // Admin ID 1 bebas
        if ((int) $user->id === 1) {
            return $next($request);
        }

        // Resolve server object (biasanya sudah model binding)
        $server = null;

        if ($serverParam instanceof Server) {
            $server = $serverParam;
        } else {
            // fallback lookup: uuidShort / uuid / id
            $key = (string) $serverParam;
            $server = Server::query()
                ->where('uuidShort', $key)
                ->orWhere('uuid', $key)
                ->orWhere('id', $key)
                ->first();
        }

        if (!$server) {
            return $this->deny($request, null, 'Access denied.');
        }

        $ownerId = $server->owner_id
            ?? $server->user_id
            ?? ($server->owner?->id ?? null)
            ?? ($server->user?->id ?? null);

        // Owner gak kebaca => block
        if ($ownerId === null) {
            $this->logAttempt($request, $server, $user, 'Owner not detected');
            return $this->deny($request, $server, 'Access denied.');
        }

        // BUKAN owner => BLOCK TOTAL (console/files/power/dll ikut)
        if ((int) $ownerId !== (int) $user->id) {
            $this->logAttempt($request, $server, $user, 'Foreign server access blocked');
            return $this->deny($request, $server, '⛔ Access denied (Protect Panel By Dezz).');
        }

        return $next($request);
    }

    private function deny(Request $request, ?Server $server, string $message)
    {
        $accept = (string) $request->header('accept', '');

        // Kalau browser minta HTML (kadang panel), kasih page HTML "serem"
        if (stripos($accept, 'text/html') !== false) {
            $html = $this->denyHtml();
            return response($html, 403)->header('Content-Type', 'text/html; charset=UTF-8');
        }

        // Default: JSON (API aman)
        return response()->json([
            'object' => 'error',
            'attributes' => [
                'status' => 403,
                'message' => $message,
            ],
        ], 403);
    }

    private function logAttempt(Request $request, Server $server, $user, string $reason): void
    {
        $username = $user->username
            ?? trim(($user->first_name ?? '') . ' ' . ($user->last_name ?? ''))
            ?? $user->email
            ?? ('User#' . ($user->id ?? 'Unknown'));

        Activity::event('server:shield.blocked')
            ->subject($server)
            ->property('attempted_by_id', $user->id ?? null)
            ->property('attempted_by', $username)
            ->property('ip', method_exists($request, 'ip') ? $request->ip() : null)
            ->property('path', $request->path())
            ->property('reason', $reason)
            ->log(sprintf('User %s baru saja mencoba mengakses server mu.', $username));
    }

    private function denyHtml(): string
    {
        return <<<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Access Denied - Protect Panel By Dezz</title>
  <style>
    :root { color-scheme: dark; }
    body {
      margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center;
      background: radial-gradient(900px 520px at 25% 20%, rgba(255,0,0,.22), transparent 60%),
                  radial-gradient(880px 560px at 80% 80%, rgba(0,170,255,.14), transparent 60%),
                  #05060a;
      font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
      color:#eaeaf2;
    }
    .card {
      width:min(920px, 92vw);
      border:1px solid rgba(255,255,255,.08);
      background: linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.02));
      border-radius:18px;
      box-shadow: 0 22px 90px rgba(0,0,0,.60);
      overflow:hidden;
    }
    .top {
      padding:22px 22px 14px;
      display:flex; gap:14px; align-items:center;
      background: linear-gradient(90deg, rgba(255,0,0,.22), rgba(255,255,255,0));
      border-bottom:1px solid rgba(255,255,255,.06);
    }
    .sig {
      width:46px; height:46px; border-radius:14px;
      display:grid; place-items:center;
      background: rgba(255,0,0,.14);
      border:1px solid rgba(255,0,0,.30);
      box-shadow: 0 0 0 6px rgba(255,0,0,.06);
      font-size:22px;
    }
    h1 { margin:0; font-size:18px; letter-spacing:.2px; }
    .sub { margin-top:4px; color: rgba(234,234,242,.72); font-size:13px; }
    .mid { padding:18px 22px 8px; }
    .code {
      margin:14px 0 6px;
      padding:14px 14px;
      border-radius:14px;
      border:1px solid rgba(255,255,255,.08);
      background: rgba(0,0,0,.25);
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
      font-size:13px;
      color:#f3f3ff;
      line-height:1.5;
      overflow:auto;
    }
    .bot {
      display:flex; justify-content:space-between; align-items:center;
      padding:14px 22px;
      border-top:1px solid rgba(255,255,255,.06);
      background: rgba(0,0,0,.18);
      color: rgba(234,234,242,.70);
      font-size:12px;
    }
    .wm { font-weight:800; color:#fff; }
    .glow { text-shadow: 0 0 18px rgba(255,0,0,.38); }
  </style>
</head>
<body>
  <div class="card">
    <div class="top">
      <div class="sig">⛔</div>
      <div>
        <h1 class="glow">ACCESS DENIED — SERVER AREA LOCKED</h1>
        <div class="sub">Owner-only access is enforced. Admin ID 1 bypass enabled.</div>
      </div>
    </div>

    <div class="mid">
      <div class="code">
HTTP/1.1 403 Forbidden<br/>
Rule: OwnerOnly + AdminID1Bypass<br/>
Module: Client / Server<br/>
WM: Protect Panel By Dezz
      </div>
    </div>

    <div class="bot">
      <div>Security Layer: <b>Dezz Shield</b> • Status: <span class="glow">ENABLED</span></div>
      <div class="wm">Protect Panel By Dezz</div>
    </div>
  </div>
</body>
</html>
HTML;
    }
}
EOF

chmod 644 "$MIDDLEWARE_FILE"
ok "Middleware dibuat: ${BOLD}${MIDDLEWARE_FILE}${NC}"
hr

info "Patch ClientApiController: pasang middleware untuk SEMUA controller client API..."
patch_client_api_controller
chmod 644 "$CLIENT_API_CTRL"
hr

ok "✅ SELESAI!"
info "Hasil: SEMUA fitur server (console/files/power/db/backups/schedules/dll) keblok kalau bukan owner."
info "Admin: ${BOLD}ID 1 bypass${NC}"
info "Log  : Activity server target => ${BOLD}User <username> baru saja mencoba mengakses server mu.${NC}"
echo -e "${WHT}${BOLD}WM:${NC} ${CYN}Protect Panel By Dezz${NC}"
hr
