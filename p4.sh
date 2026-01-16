#!/bin/bash
set -euo pipefail

# ==========================================================
# Protect Panel By Dezz - Anti Access Nodes (HARD LOCK)
# Block:
# - /admin/nodes
# - /admin/nodes/view/{id}
# - /admin/nodes/view/{id}/settings
# - /admin/nodes/view/{id}/configuration
# - /admin/nodes/view/{id}/allocation
# - /admin/nodes/view/{id}/servers
# Notes:
# - Hanya Admin ID 1 yang bisa akses.
# - Non-admin: 403 di SEMUA endpoint Nodes di atas.
# ==========================================================

BASE_DIR="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes"

TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"

# Targets (cover semua route nodes yang umum)
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

# ====== Backup semua file target ======
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
info "Menulis patch proteksi (HARD LOCK)..."
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
        // 🔒 HARD LOCK: hanya admin ID 1
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                abort(403, '⛔ ACCESS DENIED: NODES MODULE IS PROTECTED (Protect Panel By Dezz)');
            }
            return $next($request);
        });
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
# 2) NodeViewController.php  (blocks /admin/nodes/view/{id} and tabs)
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
                abort(403, '⛔ ACCESS DENIED: NODE VIEW IS PROTECTED (Protect Panel By Dezz)');
            }
            return $next($request);
        });
    }

    public function __invoke(Request $request)
    {
        // Jika route memakai single-action controller.
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

/**
 * HARD LOCK:
 * - /admin/nodes/view/{id}/settings
 * Non-admin: 403.
 */
class NodeSettingsController extends Controller
{
    public function __construct()
    {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                abort(403, '⛔ ACCESS DENIED: NODE SETTINGS LOCKED (Protect Panel By Dezz)');
            }
            return $next($request);
        });
    }

    public function index(Request $request)
    {
        abort(404);
    }

    public function update(Request $request)
    {
        abort(404);
    }
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

/**
 * HARD LOCK:
 * - /admin/nodes/view/{id}/configuration
 */
class NodeConfigurationController extends Controller
{
    public function __construct()
    {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                abort(403, '⛔ ACCESS DENIED: NODE CONFIG LOCKED (Protect Panel By Dezz)');
            }
            return $next($request);
        });
    }

    public function index(Request $request)
    {
        abort(404);
    }

    public function update(Request $request)
    {
        abort(404);
    }
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

/**
 * HARD LOCK:
 * - /admin/nodes/view/{id}/allocation
 */
class NodeAllocationController extends Controller
{
    public function __construct()
    {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                abort(403, '⛔ ACCESS DENIED: NODE ALLOCATION LOCKED (Protect Panel By Dezz)');
            }
            return $next($request);
        });
    }

    public function index(Request $request)
    {
        abort(404);
    }

    public function store(Request $request)
    {
        abort(404);
    }

    public function delete(Request $request)
    {
        abort(404);
    }
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

/**
 * HARD LOCK:
 * - /admin/nodes/view/{id}/servers
 */
class NodeServersController extends Controller
{
    public function __construct()
    {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                abort(403, '⛔ ACCESS DENIED: NODE SERVERS LOCKED (Protect Panel By Dezz)');
            }
            return $next($request);
        });
    }

    public function index(Request $request)
    {
        abort(404);
    }
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
echo -e "${RED}${BOLD}⛔ NODES AREA LOCKED.${NC} ${DIM}(Non-admin akan 403)${NC}"
hr
