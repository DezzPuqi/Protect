#!/bin/bash
set -euo pipefail

# ==========================================================
# Protect Panel By Dezz - Anti Access Nodes (HARD LOCK)
# UI + 403 HTML (SAMA KAYAK LOCK NEST)
# Block:
# - /admin/nodes
# - /admin/nodes/view/{id}
# - /admin/nodes/view/{id}/settings
# - /admin/nodes/view/{id}/configuration
# - /admin/nodes/view/{id}/allocation
# - /admin/nodes/view/{id}/servers
# Notes:
# - Hanya Admin ID 1 yang bisa akses.
# - Non-admin: 403 HTML di SEMUA endpoint Nodes di atas.
# ==========================================================

BASE_DIR="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes"
TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"

FILES=(
  "${BASE_DIR}/NodeController.php"
  "${BASE_DIR}/NodeViewController.php"
  "${BASE_DIR}/NodeSettingsController.php"
  "${BASE_DIR}/NodeConfigurationController.php"
  "${BASE_DIR}/NodeAllocationController.php"
  "${BASE_DIR}/NodeServersController.php"
)

# =========================
# UI - "HTML style" terminal
# =========================
NC="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
RED="\033[31m"; GRN="\033[32m"; YLW="\033[33m"; BLU="\033[34m"; CYN="\033[36m"; WHT="\033[37m"

hr() { echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

html_screen() {
  clear 2>/dev/null || true
  echo -e "${RED}${BOLD}<html>${NC}"
  echo -e "${RED}${BOLD}  <head>${NC}"
  echo -e "${RED}${BOLD}    <title>PROTECT PANEL</title>${NC}"
  echo -e "${RED}${BOLD}  </head>${NC}"
  echo -e "${RED}${BOLD}  <body>${NC}"
  echo -e "${RED}${BOLD}    <h1>⛔ INTRUSION SHIELD: NODES LOCKDOWN</h1>${NC}"
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
  echo -e "${DIM}Pastikan jalan sebagai root / permission tulis ke /var/www/pterodactyl.${NC}"
  exit "$code"
}
trap on_error ERR

html_screen
info "Mode     : Installer"
info "Time UTC : ${BOLD}${TIMESTAMP}${NC}"
info "Target   : ${BOLD}${BASE_DIR}${NC}"
hr

spin "Menyiapkan direktori Nodes..." mkdir -p "$BASE_DIR"
chmod 755 "$BASE_DIR"
ok "Direktori siap: $BASE_DIR"
hr

for f in "${FILES[@]}"; do
  backup="${f}.bak_${TIMESTAMP}"
  if [ -f "$f" ]; then
    spin "Backup $(basename "$f")..." mv "$f" "$backup"
    ok "Backup dibuat: ${DIM}${backup}${NC}"
  else
    warn "File tidak ada, akan dibuat baru: $(basename "$f")"
  fi
done

hr
info "Menulis patch proteksi Nodes (HTML 403 + only admin ID 1)..."
hr

# =========================
# 1) NodeController.php
# =========================
cat > "${BASE_DIR}/NodeController.php" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\Node;
use Spatie\QueryBuilder\QueryBuilder;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\View\Factory as ViewFactory;
use Illuminate\Support\Facades\Auth;

class NodeController extends Controller
{
    public function __construct(private ViewFactory $view)
    {
        // 🔒 HARD LOCK: semua endpoint Nodes hanya untuk Admin ID 1
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                return $this->denyHtml();
            }
            return $next($request);
        });
    }

    /**
     * HTML deny page (SAMA KAYAK LOCK NEST).
     */
    private function denyHtml()
    {
        $html = <<<'HTML'
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
      background: radial-gradient(800px 500px at 20% 20%, rgba(255,0,0,.18), transparent 60%),
                  radial-gradient(900px 600px at 80% 80%, rgba(0,160,255,.14), transparent 60%),
                  #07070a;
      font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
      color:#eaeaf2;
    }
    .card {
      width:min(860px, 92vw);
      border:1px solid rgba(255,255,255,.08);
      background: linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.02));
      border-radius:18px;
      box-shadow: 0 20px 80px rgba(0,0,0,.55);
      overflow:hidden;
    }
    .top {
      padding:22px 22px 14px;
      display:flex; gap:14px; align-items:center;
      background: linear-gradient(90deg, rgba(255,0,0,.18), rgba(255,255,255,0));
      border-bottom:1px solid rgba(255,255,255,.06);
    }
    .sig {
      width:44px; height:44px; border-radius:14px;
      display:grid; place-items:center;
      background: rgba(255,0,0,.14);
      border:1px solid rgba(255,0,0,.28);
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
    .pillbar { display:flex; flex-wrap:wrap; gap:8px; margin-top:10px; }
    .pill {
      font-size:12px; padding:8px 10px; border-radius:999px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      color: rgba(234,234,242,.86);
    }
    .bot {
      display:flex; justify-content:space-between; align-items:center;
      padding:14px 22px;
      border-top:1px solid rgba(255,255,255,.06);
      background: rgba(0,0,0,.18);
      color: rgba(234,234,242,.70);
      font-size:12px;
    }
    .wm { font-weight:700; color:#fff; }
    .glow { text-shadow: 0 0 18px rgba(255,0,0,.35); }
  </style>
</head>
<body>
  <div class="card">
    <div class="top">
      <div class="sig">⛔</div>
      <div>
        <h1 class="glow">ACCESS DENIED — NODES MODULE LOCKED</h1>
        <div class="sub">This area is protected. Only <b>Admin ID 1</b> is allowed.</div>
      </div>
    </div>

    <div class="mid">
      <div class="code">
HTTP/1.1 403 Forbidden<br/>
Module: Admin / Nodes<br/>
Rule: Only user_id == 1<br/>
Action: Request blocked
      </div>

      <div class="pillbar">
        <div class="pill">/admin/nodes</div>
        <div class="pill">/admin/nodes/view/*</div>
        <div class="pill">/admin/nodes/view/*/settings</div>
        <div class="pill">/admin/nodes/view/*/configuration</div>
        <div class="pill">/admin/nodes/view/*/allocation</div>
        <div class="pill">/admin/nodes/view/*/servers</div>
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

        return response($html, 403)->header('Content-Type', 'text/html; charset=UTF-8');
    }

    /**
     * /admin/nodes
     */
    public function index(Request $request): View
    {
        $nodes = QueryBuilder::for(
            Node::query()->with('location')->withCount('servers')
        )
            ->allowedFilters(['uuid', 'name'])
            ->allowedSorts(['id'])
            ->paginate(25);

        return $this->view->make('admin.nodes.index', ['nodes' => $nodes]);
    }
}
EOF

# =========================
# 2) NodeViewController.php
# =========================
cat > "${BASE_DIR}/NodeViewController.php" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Http\Controllers\Controller;

/**
 * HARD LOCK controller:
 * - /admin/nodes/view/{id}
 * - /admin/nodes/view/{id}/settings
 * - /admin/nodes/view/{id}/configuration
 * - /admin/nodes/view/{id}/allocation
 * - /admin/nodes/view/{id}/servers
 */
class NodeViewController extends Controller
{
    public function __construct()
    {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                return $this->denyHtml();
            }
            return $next($request);
        });
    }

    private function denyHtml()
    {
        $html = <<<'HTML'
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
      background: radial-gradient(800px 500px at 20% 20%, rgba(255,0,0,.18), transparent 60%),
                  radial-gradient(900px 600px at 80% 80%, rgba(0,160,255,.14), transparent 60%),
                  #07070a;
      font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
      color:#eaeaf2;
    }
    .card {
      width:min(860px, 92vw);
      border:1px solid rgba(255,255,255,.08);
      background: linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.02));
      border-radius:18px;
      box-shadow: 0 20px 80px rgba(0,0,0,.55);
      overflow:hidden;
    }
    .top {
      padding:22px 22px 14px;
      display:flex; gap:14px; align-items:center;
      background: linear-gradient(90deg, rgba(255,0,0,.18), rgba(255,255,255,0));
      border-bottom:1px solid rgba(255,255,255,.06);
    }
    .sig {
      width:44px; height:44px; border-radius:14px;
      display:grid; place-items:center;
      background: rgba(255,0,0,.14);
      border:1px solid rgba(255,0,0,.28);
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
    .pillbar { display:flex; flex-wrap:wrap; gap:8px; margin-top:10px; }
    .pill {
      font-size:12px; padding:8px 10px; border-radius:999px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      color: rgba(234,234,242,.86);
    }
    .bot {
      display:flex; justify-content:space-between; align-items:center;
      padding:14px 22px;
      border-top:1px solid rgba(255,255,255,.06);
      background: rgba(0,0,0,.18);
      color: rgba(234,234,242,.70);
      font-size:12px;
    }
    .wm { font-weight:700; color:#fff; }
    .glow { text-shadow: 0 0 18px rgba(255,0,0,.35); }
  </style>
</head>
<body>
  <div class="card">
    <div class="top">
      <div class="sig">⛔</div>
      <div>
        <h1 class="glow">ACCESS DENIED — NODES MODULE LOCKED</h1>
        <div class="sub">This area is protected. Only <b>Admin ID 1</b> is allowed.</div>
      </div>
    </div>

    <div class="mid">
      <div class="code">
HTTP/1.1 403 Forbidden<br/>
Module: Admin / Nodes<br/>
Rule: Only user_id == 1<br/>
Action: Request blocked
      </div>

      <div class="pillbar">
        <div class="pill">/admin/nodes</div>
        <div class="pill">/admin/nodes/view/*</div>
        <div class="pill">/admin/nodes/view/*/settings</div>
        <div class="pill">/admin/nodes/view/*/configuration</div>
        <div class="pill">/admin/nodes/view/*/allocation</div>
        <div class="pill">/admin/nodes/view/*/servers</div>
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

        return response($html, 403)->header('Content-Type', 'text/html; charset=UTF-8');
    }

    public function __invoke(Request $request)
    {
        // kalau route pakai single-action controller
        abort(404);
    }
}
EOF

# =========================
# 3) NodeSettingsController.php
# =========================
cat > "${BASE_DIR}/NodeSettingsController.php" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\Support\Facades\Auth;
use Illuminate\Http\Request;
use Pterodactyl\Http\Controllers\Controller;

class NodeSettingsController extends Controller
{
    public function __construct()
    {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                return $this->denyHtml();
            }
            return $next($request);
        });
    }

    private function denyHtml()
    {
        $html = <<<'HTML'
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
      background: radial-gradient(800px 500px at 20% 20%, rgba(255,0,0,.18), transparent 60%),
                  radial-gradient(900px 600px at 80% 80%, rgba(0,160,255,.14), transparent 60%),
                  #07070a;
      font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
      color:#eaeaf2;
    }
    .card {
      width:min(860px, 92vw);
      border:1px solid rgba(255,255,255,.08);
      background: linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.02));
      border-radius:18px;
      box-shadow: 0 20px 80px rgba(0,0,0,.55);
      overflow:hidden;
    }
    .top {
      padding:22px 22px 14px;
      display:flex; gap:14px; align-items:center;
      background: linear-gradient(90deg, rgba(255,0,0,.18), rgba(255,255,255,0));
      border-bottom:1px solid rgba(255,255,255,.06);
    }
    .sig {
      width:44px; height:44px; border-radius:14px;
      display:grid; place-items:center;
      background: rgba(255,0,0,.14);
      border:1px solid rgba(255,0,0,.28);
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
    .pillbar { display:flex; flex-wrap:wrap; gap:8px; margin-top:10px; }
    .pill {
      font-size:12px; padding:8px 10px; border-radius:999px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      color: rgba(234,234,242,.86);
    }
    .bot {
      display:flex; justify-content:space-between; align-items:center;
      padding:14px 22px;
      border-top:1px solid rgba(255,255,255,.06);
      background: rgba(0,0,0,.18);
      color: rgba(234,234,242,.70);
      font-size:12px;
    }
    .wm { font-weight:700; color:#fff; }
    .glow { text-shadow: 0 0 18px rgba(255,0,0,.35); }
  </style>
</head>
<body>
  <div class="card">
    <div class="top">
      <div class="sig">⛔</div>
      <div>
        <h1 class="glow">ACCESS DENIED — NODES MODULE LOCKED</h1>
        <div class="sub">This area is protected. Only <b>Admin ID 1</b> is allowed.</div>
      </div>
    </div>

    <div class="mid">
      <div class="code">
HTTP/1.1 403 Forbidden<br/>
Module: Admin / Nodes<br/>
Rule: Only user_id == 1<br/>
Action: Request blocked
      </div>

      <div class="pillbar">
        <div class="pill">/admin/nodes</div>
        <div class="pill">/admin/nodes/view/*</div>
        <div class="pill">/admin/nodes/view/*/settings</div>
        <div class="pill">/admin/nodes/view/*/configuration</div>
        <div class="pill">/admin/nodes/view/*/allocation</div>
        <div class="pill">/admin/nodes/view/*/servers</div>
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

        return response($html, 403)->header('Content-Type', 'text/html; charset=UTF-8');
    }

    public function index(Request $request) { abort(404); }
    public function update(Request $request) { abort(404); }
}
EOF

# =========================
# 4) NodeConfigurationController.php
# =========================
cat > "${BASE_DIR}/NodeConfigurationController.php" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\Support\Facades\Auth;
use Illuminate\Http\Request;
use Pterodactyl\Http\Controllers\Controller;

class NodeConfigurationController extends Controller
{
    public function __construct()
    {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                return $this->denyHtml();
            }
            return $next($request);
        });
    }

    private function denyHtml()
    {
        $html = <<<'HTML'
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
      background: radial-gradient(800px 500px at 20% 20%, rgba(255,0,0,.18), transparent 60%),
                  radial-gradient(900px 600px at 80% 80%, rgba(0,160,255,.14), transparent 60%),
                  #07070a;
      font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
      color:#eaeaf2;
    }
    .card {
      width:min(860px, 92vw);
      border:1px solid rgba(255,255,255,.08);
      background: linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.02));
      border-radius:18px;
      box-shadow: 0 20px 80px rgba(0,0,0,.55);
      overflow:hidden;
    }
    .top {
      padding:22px 22px 14px;
      display:flex; gap:14px; align-items:center;
      background: linear-gradient(90deg, rgba(255,0,0,.18), rgba(255,255,255,0));
      border-bottom:1px solid rgba(255,255,255,.06);
    }
    .sig {
      width:44px; height:44px; border-radius:14px;
      display:grid; place-items:center;
      background: rgba(255,0,0,.14);
      border:1px solid rgba(255,0,0,.28);
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
    .pillbar { display:flex; flex-wrap:wrap; gap:8px; margin-top:10px; }
    .pill {
      font-size:12px; padding:8px 10px; border-radius:999px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      color: rgba(234,234,242,.86);
    }
    .bot {
      display:flex; justify-content:space-between; align-items:center;
      padding:14px 22px;
      border-top:1px solid rgba(255,255,255,.06);
      background: rgba(0,0,0,.18);
      color: rgba(234,234,242,.70);
      font-size:12px;
    }
    .wm { font-weight:700; color:#fff; }
    .glow { text-shadow: 0 0 18px rgba(255,0,0,.35); }
  </style>
</head>
<body>
  <div class="card">
    <div class="top">
      <div class="sig">⛔</div>
      <div>
        <h1 class="glow">ACCESS DENIED — NODES MODULE LOCKED</h1>
        <div class="sub">This area is protected. Only <b>Admin ID 1</b> is allowed.</div>
      </div>
    </div>

    <div class="mid">
      <div class="code">
HTTP/1.1 403 Forbidden<br/>
Module: Admin / Nodes<br/>
Rule: Only user_id == 1<br/>
Action: Request blocked
      </div>

      <div class="pillbar">
        <div class="pill">/admin/nodes</div>
        <div class="pill">/admin/nodes/view/*</div>
        <div class="pill">/admin/nodes/view/*/settings</div>
        <div class="pill">/admin/nodes/view/*/configuration</div>
        <div class="pill">/admin/nodes/view/*/allocation</div>
        <div class="pill">/admin/nodes/view/*/servers</div>
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

        return response($html, 403)->header('Content-Type', 'text/html; charset=UTF-8');
    }

    public function index(Request $request) { abort(404); }
    public function update(Request $request) { abort(404); }
}
EOF

# =========================
# 5) NodeAllocationController.php
# =========================
cat > "${BASE_DIR}/NodeAllocationController.php" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\Support\Facades\Auth;
use Illuminate\Http\Request;
use Pterodactyl\Http\Controllers\Controller;

class NodeAllocationController extends Controller
{
    public function __construct()
    {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                return $this->denyHtml();
            }
            return $next($request);
        });
    }

    private function denyHtml()
    {
        $html = <<<'HTML'
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
      background: radial-gradient(800px 500px at 20% 20%, rgba(255,0,0,.18), transparent 60%),
                  radial-gradient(900px 600px at 80% 80%, rgba(0,160,255,.14), transparent 60%),
                  #07070a;
      font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
      color:#eaeaf2;
    }
    .card {
      width:min(860px, 92vw);
      border:1px solid rgba(255,255,255,.08);
      background: linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.02));
      border-radius:18px;
      box-shadow: 0 20px 80px rgba(0,0,0,.55);
      overflow:hidden;
    }
    .top {
      padding:22px 22px 14px;
      display:flex; gap:14px; align-items:center;
      background: linear-gradient(90deg, rgba(255,0,0,.18), rgba(255,255,255,0));
      border-bottom:1px solid rgba(255,255,255,.06);
    }
    .sig {
      width:44px; height:44px; border-radius:14px;
      display:grid; place-items:center;
      background: rgba(255,0,0,.14);
      border:1px solid rgba(255,0,0,.28);
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
    .pillbar { display:flex; flex-wrap:wrap; gap:8px; margin-top:10px; }
    .pill {
      font-size:12px; padding:8px 10px; border-radius:999px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      color: rgba(234,234,242,.86);
    }
    .bot {
      display:flex; justify-content:space-between; align-items:center;
      padding:14px 22px;
      border-top:1px solid rgba(255,255,255,.06);
      background: rgba(0,0,0,.18);
      color: rgba(234,234,242,.70);
      font-size:12px;
    }
    .wm { font-weight:700; color:#fff; }
    .glow { text-shadow: 0 0 18px rgba(255,0,0,.35); }
  </style>
</head>
<body>
  <div class="card">
    <div class="top">
      <div class="sig">⛔</div>
      <div>
        <h1 class="glow">ACCESS DENIED — NODES MODULE LOCKED</h1>
        <div class="sub">This area is protected. Only <b>Admin ID 1</b> is allowed.</div>
      </div>
    </div>

    <div class="mid">
      <div class="code">
HTTP/1.1 403 Forbidden<br/>
Module: Admin / Nodes<br/>
Rule: Only user_id == 1<br/>
Action: Request blocked
      </div>

      <div class="pillbar">
        <div class="pill">/admin/nodes</div>
        <div class="pill">/admin/nodes/view/*</div>
        <div class="pill">/admin/nodes/view/*/settings</div>
        <div class="pill">/admin/nodes/view/*/configuration</div>
        <div class="pill">/admin/nodes/view/*/allocation</div>
        <div class="pill">/admin/nodes/view/*/servers</div>
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

        return response($html, 403)->header('Content-Type', 'text/html; charset=UTF-8');
    }

    public function index(Request $request) { abort(404); }
    public function store(Request $request) { abort(404); }
    public function delete(Request $request) { abort(404); }
}
EOF

# =========================
# 6) NodeServersController.php
# =========================
cat > "${BASE_DIR}/NodeServersController.php" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\Support\Facades\Auth;
use Illuminate\Http\Request;
use Pterodactyl\Http\Controllers\Controller;

class NodeServersController extends Controller
{
    public function __construct()
    {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                return $this->denyHtml();
            }
            return $next($request);
        });
    }

    private function denyHtml()
    {
        $html = <<<'HTML'
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
      background: radial-gradient(800px 500px at 20% 20%, rgba(255,0,0,.18), transparent 60%),
                  radial-gradient(900px 600px at 80% 80%, rgba(0,160,255,.14), transparent 60%),
                  #07070a;
      font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
      color:#eaeaf2;
    }
    .card {
      width:min(860px, 92vw);
      border:1px solid rgba(255,255,255,.08);
      background: linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.02));
      border-radius:18px;
      box-shadow: 0 20px 80px rgba(0,0,0,.55);
      overflow:hidden;
    }
    .top {
      padding:22px 22px 14px;
      display:flex; gap:14px; align-items:center;
      background: linear-gradient(90deg, rgba(255,0,0,.18), rgba(255,255,255,0));
      border-bottom:1px solid rgba(255,255,255,.06);
    }
    .sig {
      width:44px; height:44px; border-radius:14px;
      display:grid; place-items:center;
      background: rgba(255,0,0,.14);
      border:1px solid rgba(255,0,0,.28);
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
    .pillbar { display:flex; flex-wrap:wrap; gap:8px; margin-top:10px; }
    .pill {
      font-size:12px; padding:8px 10px; border-radius:999px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      color: rgba(234,234,242,.86);
    }
    .bot {
      display:flex; justify-content:space-between; align-items:center;
      padding:14px 22px;
      border-top:1px solid rgba(255,255,255,.06);
      background: rgba(0,0,0,.18);
      color: rgba(234,234,242,.70);
      font-size:12px;
    }
    .wm { font-weight:700; color:#fff; }
    .glow { text-shadow: 0 0 18px rgba(255,0,0,.35); }
  </style>
</head>
<body>
  <div class="card">
    <div class="top">
      <div class="sig">⛔</div>
      <div>
        <h1 class="glow">ACCESS DENIED — NODES MODULE LOCKED</h1>
        <div class="sub">This area is protected. Only <b>Admin ID 1</b> is allowed.</div>
      </div>
    </div>

    <div class="mid">
      <div class="code">
HTTP/1.1 403 Forbidden<br/>
Module: Admin / Nodes<br/>
Rule: Only user_id == 1<br/>
Action: Request blocked
      </div>

      <div class="pillbar">
        <div class="pill">/admin/nodes</div>
        <div class="pill">/admin/nodes/view/*</div>
        <div class="pill">/admin/nodes/view/*/settings</div>
        <div class="pill">/admin/nodes/view/*/configuration</div>
        <div class="pill">/admin/nodes/view/*/allocation</div>
        <div class="pill">/admin/nodes/view/*/servers</div>
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

        return response($html, 403)->header('Content-Type', 'text/html; charset=UTF-8');
    }

    public function index(Request $request) { abort(404); }
}
EOF

# permissions
for f in "${FILES[@]}"; do
  chmod 644 "$f"
done

hr
ok "Proteksi Anti Akses Nodes berhasil dipasang (HARD LOCK)!"
info "Folder : ${BOLD}${BASE_DIR}${NC}"
info "WM     : ${BOLD}Protect Panel By Dezz${NC}"
hr
echo -e "${RED}${BOLD}⛔ NODES AREA LOCKED.${NC} ${DIM}(Non-admin akan 403 HTML)${NC}"
hr
