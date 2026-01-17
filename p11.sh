#!/bin/bash
set -euo pipefail

# ==========================================================
# Protect Panel By Dezz - SHIELD PACK (NO KERNEL PATCH)
# 1) Client Owner Shield: block all {server} access if not owner (admin id 1 bypass)
# 2) Application API Audit: log all /api/application/* usage to Activity
# 3) Admin Panel Lock (optional): lock all /admin to admin id 1 + scary deny page
#
# Anti 500:
# - No Kernel.php modifications
# - Route files wrapped safely, logging wrapped in try/catch
# ==========================================================

TS="$(date -u +"%Y-%m-%d-%H-%M-%S")"
PTERO="/var/www/pterodactyl"
WM="Protect Panel By Dezz"

# ===== TOGGLES =====
LOCK_ADMIN_PANEL_TO_ID1="true"   # set "false" kalau lu gak mau kunci seluruh /admin
LOCK_CLIENT_OWNER_ONLY="true"    # should stay true
AUDIT_APPLICATION_API="true"     # should stay true

# ===== PATHS =====
MW_DIR="${PTERO}/app/Http/Middleware/Dezz"
MW_CLIENT="${MW_DIR}/DezzClientOwnerShield.php"
MW_APP_AUDIT="${MW_DIR}/DezzApplicationApiAudit.php"
MW_ADMIN="${MW_DIR}/DezzAdminOnlyId1.php"

VIEW_DENY="${PTERO}/resources/views/errors/dezz-denied.blade.php"

ROUTE_CLIENT="${PTERO}/routes/api-client.php"
ROUTE_APP="${PTERO}/routes/api-application.php"
ROUTE_ADMIN="${PTERO}/routes/admin.php"

ADMIN_LOG_CTRL="${PTERO}/app/Http/Controllers/Admin/DezzProtectController.php"
ADMIN_LOG_VIEW="${PTERO}/resources/views/admin/dezzprotect/logs.blade.php"

# ===== helpers =====
backup_file () {
  local p="$1"
  if [ -f "$p" ]; then
    cp -a "$p" "${p}.bak_${TS}"
    echo "[OK] Backup: ${p}.bak_${TS}"
  fi
}

ensure_dir () {
  mkdir -p "$1"
  chmod 755 "$1"
}

already_wrapped () {
  local file="$1"
  grep -q "Protect Panel By Dezz" "$file" 2>/dev/null
}

echo "=========================================================="
echo "  ${WM} - SHIELD PACK (NO KERNEL PATCH)"
echo "  TS: ${TS}"
echo "=========================================================="
echo ""

# ===== 0) sanity =====
for f in "$ROUTE_CLIENT" "$ROUTE_APP" "$ROUTE_ADMIN"; do
  if [ ! -f "$f" ]; then
    echo "[XX] Missing file: $f"
    exit 1
  fi
done

# ===== 1) deny page =====
echo "[..] Writing deny page (HTML scary)..."
ensure_dir "$(dirname "$VIEW_DENY")"
backup_file "$VIEW_DENY"
cat > "$VIEW_DENY" <<'BLADE'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Access Denied</title>
  <style>
    :root { color-scheme: dark; --bg:#070911; --line:rgba(255,255,255,.09); --red:#ff2e2e; --muted:#9aa4b2; }
    body{
      margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center; padding:24px;
      background:
        radial-gradient(900px 560px at 18% 12%, rgba(255,46,46,.16), transparent 60%),
        radial-gradient(900px 560px at 84% 88%, rgba(255,46,46,.10), transparent 60%),
        var(--bg);
      font-family: ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Arial;
      color:#e5e7eb;
    }
    .card{
      width:min(920px, 100%);
      border:1px solid var(--line);
      background: linear-gradient(180deg, rgba(255,255,255,.04), rgba(255,255,255,.015));
      border-radius:18px; overflow:hidden;
      box-shadow: 0 22px 90px rgba(0,0,0,.62);
      position:relative;
    }
    .wm{
      position:absolute; right:-140px; top:60px; transform:rotate(16deg);
      font-weight:900; font-size:36px; letter-spacing:1px;
      color:rgba(255,255,255,.06);
      user-select:none; pointer-events:none;
    }
    .top{ padding:20px 22px; display:flex; gap:12px; align-items:center; border-bottom:1px solid var(--line);
      background: linear-gradient(90deg, rgba(255,46,46,.20), rgba(255,255,255,0));
    }
    .sig{
      width:46px; height:46px; border-radius:14px; display:grid; place-items:center;
      background: rgba(255,46,46,.14);
      border:1px solid rgba(255,46,46,.32);
      box-shadow: 0 0 0 6px rgba(255,46,46,.06);
      font-size:22px;
    }
    .title{ margin:0; font-size:18px; letter-spacing:.3px; }
    .sub{ margin-top:4px; color:rgba(229,231,235,.70); font-size:13px; }
    .mid{ padding:22px 22px 26px; }
    .h{ font-size:36px; margin:0 0 10px; }
    .p{ margin:0; color:var(--muted); line-height:1.6; font-size:15px; }
    .box{
      margin-top:16px; padding:14px 14px;
      border-radius:14px; border:1px solid var(--line); background:rgba(0,0,0,.26);
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
      font-size:13px; color:#f3f4f6;
    }
    .bot{ padding:14px 22px; border-top:1px solid var(--line); display:flex; justify-content:space-between; gap:12px;
      background: rgba(0,0,0,.18); color:rgba(229,231,235,.70); font-size:12px;
    }
    .glow{ text-shadow: 0 0 18px rgba(255,46,46,.36); }
    a{ color:#e5e7eb; text-decoration:none; border-bottom:1px dashed rgba(255,255,255,.25); }
  </style>
</head>
<body>
  <div class="card">
    <div class="wm">Protect Panel By Dezz</div>
    <div class="top">
      <div class="sig">X</div>
      <div>
        <div class="title glow">ACCESS DENIED - SECURITY POLICY ENFORCED</div>
        <div class="sub">Request blocked by Protect Panel By Dezz.</div>
      </div>
    </div>

    <div class="mid">
      <h1 class="h">Blocked.</h1>
      <p class="p">
        You do not have permission to access this area.<br/>
        If you think this is a mistake, contact the panel owner.
      </p>

      <div class="box">
HTTP/1.1 403 Forbidden
Policy: SUPERADMIN / OWNER ONLY
WM: Protect Panel By Dezz
      </div>

      <p class="p" style="margin-top:14px;"><a href="/">Return</a></p>
    </div>

    <div class="bot">
      <div>Shield: <b>ENABLED</b> | Status: <span class="glow">LOCKDOWN</span></div>
      <div><b>Protect Panel By Dezz</b></div>
    </div>
  </div>
</body>
</html>
BLADE
chmod 644 "$VIEW_DENY"
echo "[OK] Deny page ready."
echo ""

# ===== 2) middleware files =====
echo "[..] Writing middleware..."
ensure_dir "$MW_DIR"
backup_file "$MW_CLIENT"
backup_file "$MW_APP_AUDIT"
backup_file "$MW_ADMIN"

# 2a) Client Owner Shield
cat > "$MW_CLIENT" <<'PHP'
<?php

namespace Pterodactyl\Http\Middleware\Dezz;

use Closure;
use Illuminate\Http\Request;
use Pterodactyl\Models\Server;
use Pterodactyl\Facades\Activity;

class DezzClientOwnerShield
{
    public function handle(Request $request, Closure $next): mixed
    {
        // enforce only if route has {server}
        $serverParam = $request->route('server');
        if ($serverParam === null) {
            return $next($request);
        }

        $user = $request->user();
        if (!$user) {
            return $this->deny($request, 'Unauthorized.', 401);
        }

        // admin id 1 bypass
        if ((int) $user->id === 1) {
            return $next($request);
        }

        // resolve server
        $server = null;
        if ($serverParam instanceof Server) {
            $server = $serverParam;
        } else {
            $key = (string) $serverParam;
            $server = Server::query()
                ->where('uuidShort', $key)
                ->orWhere('uuid', $key)
                ->orWhere('id', $key)
                ->first();
        }

        if (!$server) {
            return $this->deny($request, 'Access denied.', 403);
        }

        $ownerId = $server->owner_id
            ?? $server->user_id
            ?? ($server->owner?->id ?? null)
            ?? ($server->user?->id ?? null);

        if ($ownerId === null || (int) $ownerId !== (int) $user->id) {
            $this->logAttempt($request, $server, $user, 'Foreign server access blocked');
            return $this->deny($request, 'Access denied (Protect Panel By Dezz).', 403);
        }

        return $next($request);
    }

    private function deny(Request $request, string $message, int $status): mixed
    {
        $accept = (string) $request->header('accept', '');

        // If frontend wants HTML, show scary page
        if (stripos($accept, 'text/html') !== false) {
            return response()->view('errors.dezz-denied', [], 403);
        }

        return response()->json([
            'object' => 'error',
            'attributes' => [
                'status' => $status,
                'message' => $message,
                'wm' => 'Protect Panel By Dezz',
                'threat' => ['level' => 'HIGH', 'action' => 'BLOCKED'],
            ],
        ], $status);
    }

    private function logAttempt(Request $request, Server $server, $user, string $reason): void
    {
        $username = $user->username
            ?? trim(($user->first_name ?? '') . ' ' . ($user->last_name ?? ''))
            ?? $user->email
            ?? ('User#' . ($user->id ?? 'Unknown'));

        try {
            Activity::event('dezz:client.blocked')
                ->subject($server)
                ->property('wm', 'Protect Panel By Dezz')
                ->property('attempted_by_id', $user->id ?? null)
                ->property('attempted_by', $username)
                ->property('ip', $request->ip())
                ->property('method', $request->method())
                ->property('path', '/' . ltrim($request->path(), '/'))
                ->property('reason', $reason)
                ->log(sprintf('User %s baru saja mencoba mengakses server mu.', $username));
        } catch (\Throwable $e) {
            // swallow
        }
    }
}
PHP

# 2b) Application API Audit
cat > "$MW_APP_AUDIT" <<'PHP'
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

# 2c) Admin Panel lock (ID 1 only)
cat > "$MW_ADMIN" <<'PHP'
<?php

namespace Pterodactyl\Http\Middleware\Dezz;

use Closure;
use Illuminate\Http\Request;
use Pterodactyl\Facades\Activity;

class DezzAdminOnlyId1
{
    public function handle(Request $request, Closure $next): mixed
    {
        $user = $request->user();

        if ($user && (int) $user->id === 1) {
            return $next($request);
        }

        try {
            $name = $user?->username ?? $user?->email ?? ('User#' . ($user?->id ?? 'Unknown'));
            Activity::event('dezz:admin.blocked')
                ->actor($user)
                ->property('wm', 'Protect Panel By Dezz')
                ->property('ip', $request->ip())
                ->property('method', $request->method())
                ->property('path', '/' . ltrim($request->path(), '/'))
                ->log(sprintf('Admin area access blocked for %s.', $name));
        } catch (\Throwable $e) {
            // swallow
        }

        return response()->view('errors.dezz-denied', [], 403);
    }
}
PHP

chmod 644 "$MW_CLIENT" "$MW_APP_AUDIT" "$MW_ADMIN"
echo "[OK] Middleware ready."
echo ""

# ===== 3) Wrap routes safely (NO inject, NO kernel) =====
wrap_route_file () {
  local file="$1"
  local useLine="$2"
  local groupLine="$3"

  if already_wrapped "$file"; then
    echo "[!!] Skip (already wrapped): $file"
    return 0
  fi

  backup_file "$file"

  local bak="${file}.bak_${TS}"
  local tmp="${file}.tmp_${TS}"

  {
    echo "<?php"
    echo ""
    echo "/*"
    echo " | ${WM}"
    echo " | TS: ${TS}"
    echo " */"
    echo ""
    echo "$useLine"
    echo ""
    echo "$groupLine"
    # append original content minus first php tag line
    tail -n +2 "$bak"
    echo "});"
    echo ""
  } > "$tmp"

  mv "$tmp" "$file"
  chmod 644 "$file"
  echo "[OK] Wrapped: $file"
}

if [ "$LOCK_CLIENT_OWNER_ONLY" = "true" ]; then
  echo "[..] Wrapping routes/api-client.php with client owner shield..."
  wrap_route_file \
    "$ROUTE_CLIENT" \
    "use Pterodactyl\Http\Middleware\Dezz\DezzClientOwnerShield;" \
    "Route::middleware([DezzClientOwnerShield::class])->group(function () {"
  echo ""
fi

if [ "$AUDIT_APPLICATION_API" = "true" ]; then
  echo "[..] Wrapping routes/api-application.php with application api audit..."
  wrap_route_file \
    "$ROUTE_APP" \
    "use Pterodactyl\Http\Middleware\Dezz\DezzApplicationApiAudit;" \
    "Route::middleware([DezzApplicationApiAudit::class])->group(function () {"
  echo ""
fi

if [ "$LOCK_ADMIN_PANEL_TO_ID1" = "true" ]; then
  echo "[..] Wrapping routes/admin.php with admin-only id1 lock..."
  wrap_route_file \
    "$ROUTE_ADMIN" \
    "use Pterodactyl\Http\Middleware\Dezz\DezzAdminOnlyId1;" \
    "Route::middleware([DezzAdminOnlyId1::class])->group(function () {"
  echo ""
fi

# ===== 4) (optional) Admin logs page (no sidebar injection = no risk) =====
echo "[..] Creating admin logs page (superadmin only)..."
ensure_dir "$(dirname "$ADMIN_LOG_CTRL")"
ensure_dir "$(dirname "$ADMIN_LOG_VIEW")"
backup_file "$ADMIN_LOG_CTRL"
backup_file "$ADMIN_LOG_VIEW"

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

        $logs = DB::table('activity_logs')
            ->where('event', 'like', 'dezz:%')
            ->orderByDesc('id')
            ->paginate(50);

        return view('admin.dezzprotect.logs', ['logs' => $logs]);
    }
}
PHP
chmod 644 "$ADMIN_LOG_CTRL"

cat > "$ADMIN_LOG_VIEW" <<'BLADE'
@extends('layouts.admin')

@section('title')
  Protect Panel By Dezz - Logs
@endsection

@section('content-header')
  <h1>
    Protect Panel By Dezz
    <small>Audit Logs</small>
  </h1>
  <ol class="breadcrumb">
    <li><a href="{{ route('admin.index') }}">Admin</a></li>
    <li class="active">Protect Panel By Dezz</li>
  </ol>
@endsection

@section('content')
  <style>
    .dezz-wm{ position:absolute; right:-20px; top:-10px; transform:rotate(12deg); font-weight:900; font-size:32px; opacity:.08; pointer-events:none; }
    .mono{ font-family: ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono"; font-size:12px; }
    .dezz-head{ background:linear-gradient(90deg,#111827,#7f1d1d); color:#fff; padding:14px 16px; }
    .badge-dezz{ background:#7f1d1d; }
  </style>

  <div style="position:relative;">
    <div class="dezz-wm">Protect Panel By Dezz</div>

    <div class="box">
      <div class="dezz-head">
        <b>SECURITY AUDIT LOGS</b>
        <span class="label badge-dezz pull-right">ID1 ONLY</span>
        <div style="opacity:.85;font-size:12px;margin-top:4px;">
          events: dezz:client.blocked / dezz:application-api.request / dezz:admin.blocked
        </div>
      </div>

      <div class="box-body" style="padding:0;">
        <table class="table table-hover" style="margin:0;">
          <thead>
            <tr>
              <th style="width:90px;">ID</th>
              <th style="width:230px;">Event</th>
              <th style="width:160px;">Actor</th>
              <th>Props</th>
            </tr>
          </thead>
          <tbody>
            @forelse($logs as $log)
              <tr>
                <td class="mono">#{{ $log->id }}</td>
                <td><span class="label label-danger">{{ $log->event }}</span></td>
                <td class="mono">{{ $log->actor_id ?? '-' }}</td>
                <td class="mono" style="opacity:.9;">{{ $log->properties }}</td>
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
chmod 644 "$ADMIN_LOG_VIEW"
echo "[OK] Logs page files written."
echo ""

# Add route to admin.php (inside wrapped group, safe)
if grep -q "admin.dezzprotect.logs" "$ROUTE_ADMIN"; then
  echo "[!!] Route exists (skip): admin.dezzprotect.logs"
else
  echo "[..] Adding route to admin.php: /admin/dezz-protect/logs"
  cat >> "$ROUTE_ADMIN" <<'PHP'

/*
|--------------------------------------------------------------------------
| Protect Panel By Dezz - Logs
|--------------------------------------------------------------------------
*/
Route::get('/dezz-protect/logs', [\Pterodactyl\Http\Controllers\Admin\DezzProtectController::class, 'index'])
    ->name('admin.dezzprotect.logs');

PHP
  echo "[OK] Route added."
fi

echo ""
echo "=========================================================="
echo "[OK] DONE - ${WM}"
echo "=========================================================="
echo ""
echo "Result:"
echo "- Client server intip blocked + Activity log: dezz:client.blocked"
echo "- Application API usage logged: dezz:application-api.request"
if [ "$LOCK_ADMIN_PANEL_TO_ID1" = "true" ]; then
  echo "- Admin panel locked to Admin ID 1: dezz:admin.blocked"
else
  echo "- Admin panel lock: OFF"
fi
echo ""
echo "Logs page (ID 1 only): /admin/dezz-protect/logs"
echo ""
echo "If cache issues, run (manual):"
echo "  cd /var/www/pterodactyl && php artisan route:clear && php artisan view:clear"
echo ""
