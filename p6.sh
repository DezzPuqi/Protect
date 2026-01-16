#!/bin/bash
set -euo pipefail

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Settings/IndexController.php"
TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

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
  echo -e "${RED}${BOLD}    <h1>⛔ SETTINGS LOCKDOWN ENABLED</h1>${NC}"
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
  echo -e "${DIM}Pastikan jalan sebagai root / permission tulis ke path target.${NC}"
  exit "$code"
}
trap on_error ERR

banner
info "Mode     : Installer"
info "Target   : ${BOLD}${REMOTE_PATH}${NC}"
info "Backup   : ${BOLD}${BACKUP_PATH}${NC}"
info "Time UTC : ${BOLD}${TIMESTAMP}${NC}"
hr

if [ -f "$REMOTE_PATH" ]; then
  spin "Backup file lama..." mv "$REMOTE_PATH" "$BACKUP_PATH"
  ok "Backup dibuat: ${DIM}${BACKUP_PATH}${NC}"
else
  warn "File lama tidak ditemukan, skip backup."
fi

spin "Menyiapkan direktori..." mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
ok "Direktori siap: $(dirname "$REMOTE_PATH")"
hr

info "Menulis patch proteksi Settings (HTML 403 + only admin ID 1)..."
hr

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Settings;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Helpers\SoftwareVersionService;
use Pterodactyl\Contracts\Repository\SettingsRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Settings\BaseSettingsFormRequest;

class IndexController extends Controller
{
    use AvailableLanguages;

    /**
     * IndexController constructor.
     */
    public function __construct(
        private AlertsMessageBag $alert,
        private Kernel $kernel,
        private SettingsRepositoryInterface $settings,
        private SoftwareVersionService $versionService,
        private ViewFactory $view
    ) {
        // 🔒 HARD LOCK: semua endpoint Settings hanya untuk Admin ID 1
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                return $this->denyHtml();
            }
            return $next($request);
        });
    }

    /**
     * HTML deny page (biar ga polos).
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
      background: radial-gradient(900px 520px at 25% 20%, rgba(255,0,0,.20), transparent 60%),
                  radial-gradient(880px 560px at 80% 80%, rgba(0,170,255,.14), transparent 60%),
                  #05060a;
      font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
      color:#eaeaf2;
    }
    .card {
      width:min(900px, 92vw);
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
    .wm { font-weight:800; color:#fff; }
    .glow { text-shadow: 0 0 18px rgba(255,0,0,.38); }
  </style>
</head>
<body>
  <div class="card">
    <div class="top">
      <div class="sig">⛔</div>
      <div>
        <h1 class="glow">ACCESS DENIED — SETTINGS MODULE LOCKED</h1>
        <div class="sub">Only <b>Admin ID 1</b> may access or update panel settings.</div>
      </div>
    </div>

    <div class="mid">
      <div class="code">
HTTP/1.1 403 Forbidden<br/>
Module: Admin / Settings<br/>
Rule: Only user_id == 1<br/>
Action: Request blocked
      </div>

      <div class="pillbar">
        <div class="pill">/admin/settings</div>
        <div class="pill">/admin/settings/update</div>
        <div class="pill">queue:restart blocked</div>
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
     * Render the UI for basic Panel settings.
     */
    public function index(): View
    {
        return $this->view->make('admin.settings.index', [
            'version' => $this->versionService,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * Handle settings update.
     *
     * @throws \Pterodactyl\Exceptions\Model\DataValidationException
     * @throws \Pterodactyl\Exceptions\Repository\RecordNotFoundException
     */
    public function update(BaseSettingsFormRequest $request): RedirectResponse
    {
        foreach ($request->normalize() as $key => $value) {
            $this->settings->set('settings::' . $key, $value);
        }

        $this->kernel->call('queue:restart');
        $this->alert->success(
            'Panel settings have been updated successfully and the queue worker was restarted to apply these changes.'
        )->flash();

        return redirect()->route('admin.settings');
    }
}
EOF

spin "Set permission file..." chmod 644 "$REMOTE_PATH"

hr
ok "Proteksi Anti Akses Settings berhasil dipasang!"
info "Lokasi : ${BOLD}${REMOTE_PATH}${NC}"
if [ -f "$BACKUP_PATH" ]; then
  info "Backup : ${BOLD}${BACKUP_PATH}${NC}"
else
  info "Backup : ${DIM}(tidak ada file sebelumnya)${NC}"
fi
info "Rules  : ${BOLD}Only Admin ID 1${NC}"
echo -e "${WHT}${BOLD}WM:${NC} ${CYN}Protect Panel By Dezz${NC}"
hr
