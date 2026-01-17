#!/bin/bash
set -euo pipefail

TS="$(date -u +"%Y-%m-%d-%H-%M-%S")"
WM="Protect Panel By Dezz"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️  ${WM} — Application API Lock + Audit Logs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ===== PATHS =====
MW_PATH="/var/www/pterodactyl/app/Http/Middleware/Dezz/DezzApplicationApiAudit.php"
ADMIN_API_CTRL="/var/www/pterodactyl/app/Http/Controllers/Admin/ApiController.php"
ADMIN_LOG_CTRL="/var/www/pterodactyl/app/Http/Controllers/Admin/DezzProtectController.php"

VIEW_LOG="/var/www/pterodactyl/resources/views/admin/dezzprotect/logs.blade.php"
VIEW_DENY="/var/www/pterodactyl/resources/views/errors/dezz-denied.blade.php"

ROUTE_ADMIN="/var/www/pterodactyl/routes/admin.php"
ROUTE_APP_API="/var/www/pterodactyl/routes/api-application.php"

ADMIN_LAYOUT="/var/www/pterodactyl/resources/views/layouts/admin.blade.php"

backup_file () {
  local p="$1"
  if [ -f "$p" ]; then
    cp -a "$p" "${p}.bak_${TS}"
    echo "📦 Backup: ${p}.bak_${TS}"
  fi
}

ensure_dir () {
  mkdir -p "$1"
  chmod 755 "$1"
}

# ===== 1) Middleware audit for /api/application/* (no Kernel.php) =====
echo "➡️  [1/5] Pasang middleware audit Application API..."
ensure_dir "$(dirname "$MW_PATH")"
backup_file "$MW_PATH"

cat > "$MW_PATH" <<'PHP'
<?php

namespace Pterodactyl\Http\Middleware\Dezz;

use Closure;
use Illuminate\Http\Request;
use Laravel\Sanctum\TransientToken;
use Pterodactyl\Facades\Activity;

class DezzApplicationApiAudit
{
    public function handle(Request $request, Closure $next): mixed
    {
        $user = $request->user();
        $token = $user?->currentAccessToken();

        $response = $next($request);

        // Jangan bikin panel error cuma gara-gara logging.
        try {
            $identifier = null;
            if ($token && !($token instanceof TransientToken)) {
                $identifier = $token->identifier ?? null;
            }

            Activity::event('dezz:application-api.request')
                ->actor($user)
                ->subject($user, $token)
                ->property('wm', 'Protect Panel By Dezz')
                ->property('ip', $request->ip())
                ->property('method', $request->method())
                ->property('path', '/' . ltrim($request->path(), '/'))
                ->property('status', method_exists($response, 'getStatusCode') ? $response->getStatusCode() : null)
                ->property('identifier', $identifier)
                ->log();
        } catch (\Throwable $e) {
            // swallow
        }

        return $response;
    }
}
PHP

chmod 644 "$MW_PATH"
echo "✅ Middleware audit terpasang: $MW_PATH"
echo ""

# ===== 2) Wrap routes/api-application.php with middleware (FQCN) =====
echo "➡️  [2/5] Kunci + audit semua /api/application/* via routes/api-application.php..."
if [ ! -f "$ROUTE_APP_API" ]; then
  echo "❌ File tidak ditemukan: $ROUTE_APP_API"
  exit 1
fi

backup_file "$ROUTE_APP_API"

if grep -q "DezzApplicationApiAudit" "$ROUTE_APP_API"; then
  echo "ℹ️  routes/api-application.php sudah dipatch sebelumnya (skip)."
else
  TMP="${ROUTE_APP_API}.tmp_${TS}"

  {
    echo "<?php"
    echo ""
    echo "use Pterodactyl\Http\Middleware\Dezz\DezzApplicationApiAudit;"
    echo ""
    echo "Route::middleware([DezzApplicationApiAudit::class])->group(function () {"
    # buang baris pertama "<?php" dari file asli
    tail -n +2 "${ROUTE_APP_API}.bak_${TS}"
    echo "});"
    echo ""
  } > "$TMP"

  mv "$TMP" "$ROUTE_APP_API"
  chmod 644 "$ROUTE_APP_API"
  echo "✅ routes/api-application.php berhasil diwrap audit middleware."
fi
echo ""

# ===== 3) Pretty deny page (HTML) =====
echo "➡️  [3/5] Buat halaman deny yang ada tampilannya..."
ensure_dir "$(dirname "$VIEW_DENY")"
backup_file "$VIEW_DENY"

cat > "$VIEW_DENY" <<'BLADE'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Access Denied</title>
    <style>
        :root { --bg:#07090f; --card:#0c1020; --red:#ff2e2e; --muted:#94a3b8; --line:rgba(255,255,255,.08); }
        body{ margin:0; font-family:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Ubuntu; background:radial-gradient(900px 600px at 15% 10%, rgba(255,46,46,.14), transparent 60%), radial-gradient(900px 600px at 85% 90%, rgba(255,46,46,.10), transparent 60%), var(--bg); color:#e5e7eb; }
        .wrap{ min-height:100vh; display:flex; align-items:center; justify-content:center; padding:24px; }
        .card{ width:min(820px,100%); background:linear-gradient(180deg, rgba(255,255,255,.03), rgba(255,255,255,.01)); border:1px solid var(--line); border-radius:18px; overflow:hidden; box-shadow:0 22px 70px rgba(0,0,0,.55); position:relative; }
        .top{ padding:20px 24px; border-bottom:1px solid var(--line); display:flex; gap:12px; align-items:center; }
        .dot{ width:10px; height:10px; border-radius:99px; background:var(--red); box-shadow:0 0 0 6px rgba(255,46,46,.12); }
        .title{ font-size:18px; letter-spacing:.2px; }
        .body{ padding:26px 24px 30px; }
        .h{ font-size:34px; margin:0 0 10px; }
        .p{ margin:0; color:var(--muted); line-height:1.55; font-size:15px; }
        .box{ margin-top:18px; background:rgba(0,0,0,.28); border:1px solid var(--line); border-radius:14px; padding:14px 14px; }
        .row{ display:flex; flex-wrap:wrap; gap:10px; margin-top:12px; }
        .chip{ border:1px solid var(--line); background:rgba(255,255,255,.02); padding:8px 10px; border-radius:999px; color:#cbd5e1; font-size:12px; }
        .wm{ position:absolute; right:-110px; top:70px; transform:rotate(18deg); font-weight:800; font-size:34px; color:rgba(255,255,255,.05); letter-spacing:1px; user-select:none; }
        .skull{ color:var(--red); font-weight:900; }
        a{ color:#e5e7eb; text-decoration:none; border-bottom:1px dashed rgba(255,255,255,.25); }
    </style>
</head>
<body>
<div class="wrap">
    <div class="card">
        <div class="wm">Protect Panel By Dezz</div>
        <div class="top">
            <div class="dot"></div>
            <div class="title"><span class="skull">🚫</span> ACCESS DENIED</div>
        </div>
        <div class="body">
            <h1 class="h">You are not allowed.</h1>
            <p class="p">
                Request blocked by <b>Protect Panel By Dezz</b>.<br>
                Jika kamu merasa ini salah, hubungi pemilik panel.
            </p>

            <div class="box">
                <div class="p"><b>Reason:</b> Insufficient privilege (Only Admin ID 1).</div>
                <div class="row">
                    <div class="chip">WM: Protect Panel By Dezz</div>
                    <div class="chip">Status: 403</div>
                    <div class="chip">Policy: SUPERADMIN ONLY</div>
                </div>
            </div>

            <div class="p" style="margin-top:16px;">
                <a href="/">Return</a>
            </div>
        </div>
    </div>
</div>
</body>
</html>
BLADE

chmod 644 "$VIEW_DENY"
echo "✅ Deny page dibuat: $VIEW_DENY"
echo ""

# ===== 4) Lock Admin API Keys page + log create/delete keys =====
echo "➡️  [4/5] Kunci menu Admin → Application API Keys (create/store/delete) + log..."
if [ ! -f "$ADMIN_API_CTRL" ]; then
  echo "❌ File tidak ditemukan: $ADMIN_API_CTRL"
  exit 1
fi

backup_file "$ADMIN_API_CTRL"

cat > "$ADMIN_API_CTRL" <<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\Http\Request;
use Illuminate\View\View;
use Illuminate\Http\Response;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\Factory as ViewFactory;
use Prologue\Alerts\AlertsMessageBag;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Models\ApiKey;
use Pterodactyl\Services\Api\KeyCreationService;
use Pterodactyl\Services\Acl\Api\AdminAcl;
use Pterodactyl\Contracts\Repository\ApiKeyRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Api\StoreApplicationApiKeyRequest;
use Pterodactyl\Facades\Activity;

class ApiController extends Controller
{
    public function __construct(
        private AlertsMessageBag $alert,
        private ApiKeyRepositoryInterface $repository,
        private KeyCreationService $keyCreationService,
        private ViewFactory $view
    ) {
    }

    private function denyIfNotId1(Request $request): ?Response
    {
        $u = $request->user();
        if (!$u || (int) $u->id !== 1) {
            // tampilannya cakep, bukan abort polos
            return response()->view('errors.dezz-denied', [], 403);
        }
        return null;
    }

    public function index(Request $request): View|Response
    {
        if ($resp = $this->denyIfNotId1($request)) return $resp;

        return $this->view->make('admin.api.index', [
            'keys' => $this->repository->getApplicationKeys($request->user()),
        ]);
    }

    public function create(Request $request): View|Response
    {
        if ($resp = $this->denyIfNotId1($request)) return $resp;

        $resources = AdminAcl::getResourceList();
        sort($resources);

        return $this->view->make('admin.api.new', [
            'resources' => $resources,
            'permissions' => [
                'r' => AdminAcl::READ,
                'rw' => AdminAcl::READ | AdminAcl::WRITE,
                'n' => AdminAcl::NONE,
            ],
        ]);
    }

    public function store(StoreApplicationApiKeyRequest $request): RedirectResponse|Response
    {
        if ($resp = $this->denyIfNotId1($request)) return $resp;

        $this->keyCreationService->setKeyType(ApiKey::TYPE_APPLICATION)->handle([
            'memo' => $request->input('memo'),
            'user_id' => $request->user()->id,
        ], $request->getKeyPermissions());

        // log ke activity
        try {
            Activity::event('dezz:admin-api-key.created')
                ->actor($request->user())
                ->property('wm', 'Protect Panel By Dezz')
                ->property('ip', $request->ip())
                ->property('memo', $request->input('memo'))
                ->log();
        } catch (\Throwable $e) {
            // swallow
        }

        $this->alert->success('A new application API key has been generated for your account.')->flash();
        return redirect()->route('admin.api.index');
    }

    public function delete(Request $request, string $identifier): Response
    {
        if ($resp = $this->denyIfNotId1($request)) return $resp;

        $this->repository->deleteApplicationKey($request->user(), $identifier);

        // log ke activity
        try {
            Activity::event('dezz:admin-api-key.deleted')
                ->actor($request->user())
                ->property('wm', 'Protect Panel By Dezz')
                ->property('ip', $request->ip())
                ->property('identifier', $identifier)
                ->log();
        } catch (\Throwable $e) {
            // swallow
        }

        return response('', 204);
    }
}
PHP

chmod 644 "$ADMIN_API_CTRL"
echo "✅ ApiController locked + logging."
echo ""

# ===== 5) Admin page: Dezz logs + sidebar tab =====
echo "➡️  [5/5] Tambah halaman log + sidebar tab..."

# 5a Controller
ensure_dir "$(dirname "$ADMIN_LOG_CTRL")"
backup_file "$ADMIN_LOG_CTRL"

cat > "$ADMIN_LOG_CTRL" <<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;
use Illuminate\Http\Response;
use Pterodactyl\Http\Controllers\Controller;

class DezzProtectController extends Controller
{
    public function index(Request $request): View|Response
    {
        $u = $request->user();
        if (!$u || (int) $u->id !== 1) {
            return response()->view('errors.dezz-denied', [], 403);
        }

        $q = DB::table('activity_logs')
            ->where(function ($w) {
                $w->where('event', 'like', 'dezz:%')
                  ->orWhere('event', '=', 'auth:ip-blocked');
            })
            ->orderByDesc('id');

        $logs = $q->paginate(50);

        return view('admin.dezzprotect.logs', [
            'logs' => $logs,
        ]);
    }
}
PHP

chmod 644 "$ADMIN_LOG_CTRL"

# 5b View
ensure_dir "$(dirname "$VIEW_LOG")"
backup_file "$VIEW_LOG"

cat > "$VIEW_LOG" <<'BLADE'
@extends('layouts.admin')

@section('title')
    Protect Panel By Dezz — Logs
@endsection

@section('content-header')
    <h1>
        Protect Panel By Dezz
        <small>Application API Audit & Admin Key Events</small>
    </h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Protect Panel By Dezz</li>
    </ol>
@endsection

@section('content')
    <style>
        .dezz-wrap{ position:relative; }
        .dezz-wm{
            position:absolute; right:-20px; top:-10px; transform:rotate(12deg);
            font-weight:900; font-size:32px; letter-spacing:1px; opacity:.10; pointer-events:none;
        }
        .dezz-card{ border-radius:14px; overflow:hidden; border:1px solid rgba(0,0,0,.08); }
        .dezz-head{
            background:linear-gradient(90deg, #111827, #7f1d1d);
            color:#fff; padding:14px 16px;
        }
        .dezz-head b{ letter-spacing:.4px; }
        .dezz-sub{ opacity:.85; font-size:12px; }
        .dezz-table td{ vertical-align:top; font-size:12px; }
        .badge-dezz{ background:#7f1d1d; }
        .mono{ font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono"; }
        .dangerline{ color:#991b1b; font-weight:700; }
    </style>

    <div class="dezz-wrap">
        <div class="dezz-wm">Protect Panel By Dezz</div>

        <div class="box dezz-card">
            <div class="dezz-head">
                <div style="display:flex;justify-content:space-between;gap:12px;align-items:center;">
                    <div>
                        <b>🛡️ SECURITY AUDIT LOGS</b>
                        <div class="dezz-sub">Tracks Application API usage + Admin API key create/delete</div>
                    </div>
                    <span class="label badge-dezz">SUPERADMIN ONLY</span>
                </div>
            </div>

            <div class="box-body" style="padding:0;">
                <table class="table table-hover dezz-table" style="margin:0;">
                    <thead>
                        <tr>
                            <th style="width:90px;">ID</th>
                            <th style="width:220px;">Event</th>
                            <th style="width:220px;">Actor</th>
                            <th>Details</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($logs as $log)
                            @php
                                $props = json_decode($log->properties ?? '{}', true) ?: [];
                                $ip = $props['ip'] ?? null;
                                $path = $props['path'] ?? null;
                                $method = $props['method'] ?? null;
                                $status = $props['status'] ?? null;
                                $identifier = $props['identifier'] ?? null;
                                $memo = $props['memo'] ?? null;
                            @endphp
                            <tr>
                                <td class="mono">#{{ $log->id }}</td>
                                <td>
                                    <span class="label label-danger">{{ $log->event }}</span>
                                    @if($status)
                                        <span class="label label-default mono">{{ $status }}</span>
                                    @endif
                                </td>
                                <td class="mono">
                                    @if(!empty($log->actor_id))
                                        user_id={{ $log->actor_id }}
                                    @else
                                        -
                                    @endif
                                </td>
                                <td class="mono">
                                    @if($method || $path)
                                        <span class="dangerline">{{ $method }} {{ $path }}</span><br>
                                    @endif
                                    @if($ip)
                                        ip={{ $ip }}<br>
                                    @endif
                                    @if($identifier)
                                        key={{ $identifier }}<br>
                                    @endif
                                    @if($memo)
                                        memo="{{ $memo }}"<br>
                                    @endif
                                    <span style="opacity:.65;">raw={{ $log->properties }}</span>
                                </td>
                            </tr>
                        @empty
                            <tr><td colspan="4" class="text-center">No logs yet.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>

            <div class="box-footer">
                {{ $logs->links() }}
            </div>
        </div>
    </div>
@endsection
BLADE

chmod 644 "$VIEW_LOG"

# 5c Route admin
if [ -f "$ROUTE_ADMIN" ]; then
  backup_file "$ROUTE_ADMIN"

  if grep -q "admin.dezzprotect.logs" "$ROUTE_ADMIN"; then
    echo "ℹ️  routes/admin.php sudah ada route dezzprotect (skip)."
  else
    cat >> "$ROUTE_ADMIN" <<'PHP'

/*
|--------------------------------------------------------------------------
| Protect Panel By Dezz
|--------------------------------------------------------------------------
*/
Route::get('/dezz-protect/logs', [\Pterodactyl\Http\Controllers\Admin\DezzProtectController::class, 'index'])
    ->name('admin.dezzprotect.logs');

PHP
    echo "✅ Route ditambahkan ke routes/admin.php"
  fi
else
  echo "⚠️ routes/admin.php tidak ditemukan. Route tidak ditambahkan."
fi

# 5d Sidebar (best-effort, gak maksa biar gak 500)
if [ -f "$ADMIN_LAYOUT" ]; then
  backup_file "$ADMIN_LAYOUT"

  if grep -q "admin.dezzprotect.logs" "$ADMIN_LAYOUT"; then
    echo "ℹ️  Sidebar sudah ada menu Dezz (skip)."
  else
    # sisipkan sebelum penutup </ul> pertama yang ketemu (best effort)
    # kalau struktur beda, ini tetap aman (paling cuma gak kesisip).
    sed -i '0,/<\/ul>/s//    <li>\n        <a href="{{ route('\''admin.dezzprotect.logs'\'') }}">\n            <i class="fa fa-shield"></i> <span>Protect Panel By Dezz</span>\n            <small class="label pull-right bg-red">LOCK</small>\n        <\/a>\n    <\/li>\n<\/ul>/' "$ADMIN_LAYOUT" || true
    echo "✅ Sidebar patch dicoba (best-effort)."
  fi
else
  echo "⚠️ Admin layout tidak ditemukan: $ADMIN_LAYOUT (skip sidebar)."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ SELESAI — ${WM}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 IMPORTANT:"
echo "1) Kalau panel pakai route cache, jalankan:"
echo "   cd /var/www/pterodactyl && php artisan route:clear && php artisan view:clear"
echo ""
echo "2) Menu log: /admin/dezz-protect/logs"
echo "3) Semua Application API requests ke-log event: dezz:application-api.request"
echo "4) Create/Delete API key ke-log: dezz:admin-api-key.created / dezz:admin-api-key.deleted"
echo ""
