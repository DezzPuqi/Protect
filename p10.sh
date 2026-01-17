#!/bin/bash
set -euo pipefail

# =========================
# Protect Panel By Dezz - PLTA + Logs (Admin ID 1 Only)
# NO Kernel.php touched.
# =========================

PANEL_DIR="/var/www/pterodactyl"
ROUTES_FILE="${PANEL_DIR}/routes/admin.php"

CTRL_DIR="${PANEL_DIR}/app/Http/Controllers/Admin/Plta"
MODEL_DIR="${PANEL_DIR}/app/Models"
VIEW_DIR="${PANEL_DIR}/resources/views/admin/plta"
MIG_DIR="${PANEL_DIR}/database/migrations"

TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"
MIG_TS="$(date -u +"%Y_%m_%d_%H%M%S")"

# =========================
# UI
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
  echo -e "${RED}${BOLD}    <h1>⛔ PLTA MODULE + LOGS ENABLED</h1>${NC}"
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
  echo -e "${DIM}Pastikan jalan sebagai root / folder panel benar: ${PANEL_DIR}${NC}"
  exit "$code"
}
trap on_error ERR

backup_if_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    local b="${f}.bak_${TIMESTAMP}"
    spin "Backup $(basename "$f")..." cp -a "$f" "$b"
    ok "Backup dibuat: ${DIM}${b}${NC}"
  fi
}

banner
info "Mode     : Installer"
info "Panel Dir : ${BOLD}${PANEL_DIR}${NC}"
info "Time UTC  : ${BOLD}${TIMESTAMP}${NC}"
hr

# sanity
if [ ! -d "$PANEL_DIR" ]; then
  fail "Folder panel tidak ditemukan: $PANEL_DIR"
  exit 1
fi
if [ ! -f "$ROUTES_FILE" ]; then
  fail "routes/admin.php tidak ditemukan: $ROUTES_FILE"
  exit 1
fi

spin "Menyiapkan folder..." mkdir -p "$CTRL_DIR" "$MODEL_DIR" "$VIEW_DIR" "$MIG_DIR"
chmod 755 "$CTRL_DIR" "$VIEW_DIR" || true

backup_if_exists "$ROUTES_FILE"

# backup target files if exist
backup_if_exists "${CTRL_DIR}/PltaController.php"
backup_if_exists "${MODEL_DIR}/PltaLog.php"
backup_if_exists "${VIEW_DIR}/index.blade.php"
backup_if_exists "${VIEW_DIR}/logs.blade.php"

hr
info "Menulis Model + Controller + Views + Migration..."
hr

# =========================
# Migration
# =========================
MIG_FILE="${MIG_DIR}/${MIG_TS}_create_plta_logs_table.php"
cat > "$MIG_FILE" <<'EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('plta_logs', function (Blueprint $table) {
            $table->id();
            $table->string('pltaown', 191)->index();              // contoh: plta_kkwkwkkkd
            $table->string('usernameown', 191);                  // contoh: Dezz
            $table->string('lastcreate', 191)->nullable();       // contoh: TestUser1 (kalau kosong => "-")
            $table->string('quota', 64)->nullable();             // contoh: 1Gb (kalau kosong => "-")
            $table->unsignedBigInteger('created_by')->nullable();// user_id yang input log
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('plta_logs');
    }
};
EOF
chmod 644 "$MIG_FILE"

# =========================
# Model
# =========================
cat > "${MODEL_DIR}/PltaLog.php" <<'EOF'
<?php

namespace Pterodactyl\Models;

use Illuminate\Database\Eloquent\Model;

class PltaLog extends Model
{
    protected $table = 'plta_logs';

    protected $fillable = [
        'pltaown',
        'usernameown',
        'lastcreate',
        'quota',
        'created_by',
    ];
}
EOF
chmod 644 "${MODEL_DIR}/PltaLog.php"

# =========================
# Controller
# =========================
cat > "${CTRL_DIR}/PltaController.php" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Plta;

use Illuminate\Http\Request;
use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Models\PltaLog;

class PltaController extends Controller
{
    public function __construct()
    {
        // 🔒 HARD LOCK: cuma Admin ID 1
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
        <h1 class="glow">ACCESS DENIED — PLTA MODULE LOCKED</h1>
        <div class="sub">This area is protected. Only <b>Admin ID 1</b> is allowed.</div>
      </div>
    </div>

    <div class="mid">
      <div class="code">
HTTP/1.1 403 Forbidden<br/>
Module: Admin / PLTA<br/>
Rule: Only user_id == 1<br/>
Action: Request blocked
      </div>

      <div class="pillbar">
        <div class="pill">/admin/plta</div>
        <div class="pill">/admin/plta/logs</div>
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

    public function index(): View
    {
        $recent = PltaLog::query()->latest('id')->limit(10)->get();

        return view('admin.plta.index', [
            'recent' => $recent,
        ]);
    }

    public function logs(Request $request): View
    {
        $q = trim((string) $request->query('q', ''));

        $logs = PltaLog::query()
            ->when($q !== '', function ($query) use ($q) {
                $query->where('pltaown', 'like', "%{$q}%")
                      ->orWhere('usernameown', 'like', "%{$q}%")
                      ->orWhere('lastcreate', 'like', "%{$q}%")
                      ->orWhere('quota', 'like', "%{$q}%");
            })
            ->latest('id')
            ->paginate(25)
            ->appends(['q' => $q]);

        return view('admin.plta.logs', [
            'logs' => $logs,
            'q' => $q,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $v = Validator::make($request->all(), [
            'pltaown'     => ['required', 'string', 'max:191'],
            'usernameown' => ['required', 'string', 'max:191'],
            'lastcreate'  => ['nullable', 'string', 'max:191'],
            'quota'       => ['nullable', 'string', 'max:64'],
        ]);

        $data = $v->validate();

        // normalize: kosong => null biar view tampil "-"
        $data['lastcreate'] = isset($data['lastcreate']) && trim($data['lastcreate']) !== '' ? trim($data['lastcreate']) : null;
        $data['quota'] = isset($data['quota']) && trim($data['quota']) !== '' ? trim($data['quota']) : null;
        $data['created_by'] = Auth::id();

        PltaLog::query()->create($data);

        return redirect()->route('admin.plta.index')->with('success', 'PLTA log berhasil ditambah.');
    }
}
EOF
chmod 644 "${CTRL_DIR}/PltaController.php"

# =========================
# Views
# =========================
cat > "${VIEW_DIR}/index.blade.php" <<'EOF'
@extends('layouts.admin')

@section('title')
    PLTA
@endsection

@section('content-header')
    <h1>PLTA <small>Create / Entry</small></h1>
@endsection

@section('content')
    @if (session('success'))
        <div class="alert alert-success">{{ session('success') }}</div>
    @endif

    <div class="nav-tabs-custom">
        <ul class="nav nav-tabs">
            <li class="active"><a href="{{ route('admin.plta.index') }}">Create</a></li>
            <li><a href="{{ route('admin.plta.logs') }}">Logs</a></li>
        </ul>

        <div class="tab-content">
            <div class="tab-pane active">
                <form method="POST" action="{{ route('admin.plta.store') }}">
                    @csrf

                    <div class="row">
                        <div class="col-md-6">
                            <div class="box box-primary">
                                <div class="box-header with-border">
                                    <h3 class="box-title">Tambah Log</h3>
                                </div>
                                <div class="box-body">
                                    <div class="form-group">
                                        <label>pltaown</label>
                                        <input name="pltaown" class="form-control" placeholder="plta_xxxxx" value="{{ old('pltaown') }}" required>
                                        @error('pltaown') <p class="text-danger">{{ $message }}</p> @enderror
                                    </div>

                                    <div class="form-group">
                                        <label>usernameown</label>
                                        <input name="usernameown" class="form-control" placeholder="Owner username" value="{{ old('usernameown') }}" required>
                                        @error('usernameown') <p class="text-danger">{{ $message }}</p> @enderror
                                    </div>

                                    <div class="form-group">
                                        <label>lastcreate (username root panel)</label>
                                        <input name="lastcreate" class="form-control" placeholder="TestUser1 / boleh kosong" value="{{ old('lastcreate') }}">
                                        @error('lastcreate') <p class="text-danger">{{ $message }}</p> @enderror
                                    </div>

                                    <div class="form-group">
                                        <label>quota</label>
                                        <input name="quota" class="form-control" placeholder="1Gb / boleh kosong" value="{{ old('quota') }}">
                                        @error('quota') <p class="text-danger">{{ $message }}</p> @enderror
                                    </div>
                                </div>
                                <div class="box-footer">
                                    <button class="btn btn-primary" type="submit">Save Log</button>
                                    <a class="btn btn-default" href="{{ route('admin.plta.logs') }}">Open Logs</a>
                                </div>
                            </div>
                        </div>

                        <div class="col-md-6">
                            <div class="box box-info">
                                <div class="box-header with-border">
                                    <h3 class="box-title">Recent Logs (10 terakhir)</h3>
                                </div>
                                <div class="box-body table-responsive no-padding">
                                    <table class="table table-hover">
                                        <thead>
                                            <tr>
                                                <th>pltaown</th>
                                                <th>usernameown</th>
                                                <th>lastcreate</th>
                                                <th>quota</th>
                                                <th>time</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            @forelse ($recent as $r)
                                                <tr>
                                                    <td>{{ $r->pltaown }}</td>
                                                    <td>{{ $r->usernameown }}</td>
                                                    <td>{{ $r->lastcreate ?? '-' }}</td>
                                                    <td>{{ $r->quota ?? '-' }}</td>
                                                    <td>{{ $r->created_at }}</td>
                                                </tr>
                                            @empty
                                                <tr><td colspan="5" class="text-muted">Belum ada log.</td></tr>
                                            @endforelse
                                        </tbody>
                                    </table>
                                </div>
                                <div class="box-footer">
                                    Contoh: <code>plta_kkwkwkkkd | Dezz | TestUser1 | non_admin/admin | 1Gb</code>
                                </div>
                            </div>
                        </div>
                    </div>

                </form>
            </div>
        </div>
    </div>
@endsection
EOF
chmod 644 "${VIEW_DIR}/index.blade.php"

cat > "${VIEW_DIR}/logs.blade.php" <<'EOF'
@extends('layouts.admin')

@section('title')
    PLTA Logs
@endsection

@section('content-header')
    <h1>PLTA <small>Logs</small></h1>
@endsection

@section('content')
    <div class="nav-tabs-custom">
        <ul class="nav nav-tabs">
            <li><a href="{{ route('admin.plta.index') }}">Create</a></li>
            <li class="active"><a href="{{ route('admin.plta.logs') }}">Logs</a></li>
        </ul>

        <div class="tab-content">
            <div class="tab-pane active">

                <form method="GET" action="{{ route('admin.plta.logs') }}" class="row" style="margin-bottom: 10px;">
                    <div class="col-md-6">
                        <div class="input-group">
                            <input class="form-control" name="q" value="{{ $q }}" placeholder="Search pltaown / owner / lastcreate / quota">
                            <span class="input-group-btn">
                                <button class="btn btn-primary" type="submit">Search</button>
                                <a class="btn btn-default" href="{{ route('admin.plta.logs') }}">Reset</a>
                            </span>
                        </div>
                    </div>
                </form>

                <div class="box box-primary">
                    <div class="box-header with-border">
                        <h3 class="box-title">Logs</h3>
                    </div>

                    <div class="box-body table-responsive no-padding">
                        <table class="table table-hover">
                            <thead>
                                <tr>
                                    <th>#</th>
                                    <th>pltaown</th>
                                    <th>usernameown</th>
                                    <th>lastcreate</th>
                                    <th>quota</th>
                                    <th>created_at</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse ($logs as $l)
                                    <tr>
                                        <td>{{ $l->id }}</td>
                                        <td>{{ $l->pltaown }}</td>
                                        <td>{{ $l->usernameown }}</td>
                                        <td>{{ $l->lastcreate ?? '-' }}</td>
                                        <td>{{ $l->quota ?? '-' }}</td>
                                        <td>{{ $l->created_at }}</td>
                                    </tr>
                                @empty
                                    <tr><td colspan="6" class="text-muted">Belum ada data.</td></tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>

                    <div class="box-footer">
                        {!! $logs->links() !!}
                    </div>
                </div>

            </div>
        </div>
    </div>
@endsection
EOF
chmod 644 "${VIEW_DIR}/logs.blade.php"

# =========================
# Patch routes/admin.php (append once)
# =========================
MARKER_START="/* === PLTA MODULE (Protect Panel By Dezz) START === */"
MARKER_END="/* === PLTA MODULE (Protect Panel By Dezz) END === */"

if grep -qF "$MARKER_START" "$ROUTES_FILE"; then
  warn "routes/admin.php sudah ada PLTA block, skip patch routes."
else
  spin "Patch routes/admin.php..." bash -c "cat >> '$ROUTES_FILE' <<'ROUTES'

${MARKER_START}
Route::group(['prefix' => 'plta', 'as' => 'plta.'], function () {
    Route::get('/', [\\Pterodactyl\\Http\\Controllers\\Admin\\Plta\\PltaController::class, 'index'])->name('index');
    Route::post('/', [\\Pterodactyl\\Http\\Controllers\\Admin\\Plta\\PltaController::class, 'store'])->name('store');
    Route::get('/logs', [\\Pterodactyl\\Http\\Controllers\\Admin\\Plta\\PltaController::class, 'logs'])->name('logs');
});
${MARKER_END}

ROUTES"
  ok "Routes ditambah (admin.plta.*)."
fi

hr
ok "PLTA + Logs berhasil dipasang!"
info "Open: ${BOLD}/admin/plta${NC}"
info "Logs: ${BOLD}/admin/plta/logs${NC}"
info "Next: jalankan migrate:"
echo -e "${WHT}${BOLD}  cd ${PANEL_DIR} && php artisan migrate --force${NC}"
hr
echo -e "${WHT}${BOLD}WM:${NC} ${CYN}Protect Panel By Dezz${NC}"
hr
