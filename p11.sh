#!/bin/bash

set -e

PANEL_ROOT="/var/www/pterodactyl"

API_BASE_CONTROLLER="$PANEL_ROOT/app/Http/Controllers/Api/Application/ApplicationApiController.php"
ADMIN_CONTROLLER="$PANEL_ROOT/app/Http/Controllers/Admin/DezzProtectController.php"
ADMIN_VIEW="$PANEL_ROOT/resources/views/admin/dezz-protect/index.blade.php"
ADMIN_ROUTES="$PANEL_ROOT/routes/admin.php"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              🛡️  Protect Panel By Dezz (AUDIT)               ║"
echo "║         Application API Lock + Activity Log + UI             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

backup_file () {
  local f="$1"
  if [ -f "$f" ]; then
    mv "$f" "${f}.bak_${TIMESTAMP}"
    echo "📦 Backup: ${f}.bak_${TIMESTAMP}"
  fi
}

write_file () {
  local f="$1"
  mkdir -p "$(dirname "$f")"
  chmod 755 "$(dirname "$f")"
  cat > "$f"
  chmod 644 "$f"
  echo "✅ Write: $f"
}

echo "🚀 Pasang proteksi + audit Application API..."
backup_file "$API_BASE_CONTROLLER"

write_file "$API_BASE_CONTROLLER" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Application;

use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Collection;
use Illuminate\Container\Container;
use Illuminate\Support\Facades\Log;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Extensions\Spatie\Fractalistic\Fractal;
use Throwable;

abstract class ApplicationApiController extends Controller
{
    protected Fractal $fractal;
    protected Request $request;

    /**
     * ApplicationApiController constructor.
     */
    public function __construct()
    {
        Container::getInstance()->call([$this, 'loadDependencies']);

        /**
         * 🛡️ Protect Panel By Dezz
         * - Audit semua /api/application/*
         * - Block aksi sensitif tertentu kalau bukan Admin ID 1
         * - Anti 500: semua logging dibungkus try/catch
         */
        $this->middleware(function ($request, $next) {
            $user = $request->user(); // user dari Application API key
            $path = '/' . ltrim((string) $request->path(), '/');
            $method = strtoupper((string) $request->method());
            $ip = (string) $request->ip();

            // ======= PRE-BLOCK RULES (sebelum controller jalan) =======
            try {
                if ($user && (int) $user->id !== 1) {
                    // Block create user root lewat Application API
                    // POST /api/application/users  dengan root_admin=true
                    if ($method === 'POST' && preg_match('#^/api/application/users$#', $path)) {
                        $rootAdmin = $request->boolean('root_admin', false);
                        if ($rootAdmin) {
                            $this->logBlocked($request, 'create_root_user_blocked', [
                                'reason' => 'root_admin_create_denied',
                            ]);

                            return new JsonResponse([
                                'errors' => [[
                                    'code' => 'AccessDeniedException',
                                    'status' => '403',
                                    'detail' => '🚫 𝗔𝗸𝘀𝗲𝘀 𝗗𝗶𝘁𝗼𝗹𝗮𝗸. Root user hanya bisa dibuat oleh Admin ID 1. (Protect Panel By Dezz)',
                                ]],
                            ], 403);
                        }
                    }

                    // Block edit user jadi root lewat Application API
                    // PATCH /api/application/users/{id} dengan root_admin=true
                    if (in_array($method, ['PATCH', 'PUT'], true) && preg_match('#^/api/application/users/\d+$#', $path)) {
                        if ($request->has('root_admin') && $request->boolean('root_admin', false) === true) {
                            $this->logBlocked($request, 'promote_root_user_blocked', [
                                'reason' => 'root_admin_promote_denied',
                            ]);

                            return new JsonResponse([
                                'errors' => [[
                                    'code' => 'AccessDeniedException',
                                    'status' => '403',
                                    'detail' => '🚫 𝗔𝗸𝘀𝗲𝘀 𝗗𝗶𝘁𝗼𝗹𝗮𝗸. Promote root hanya oleh Admin ID 1. (Protect Panel By Dezz)',
                                ]],
                            ], 403);
                        }
                    }
                }
            } catch (Throwable $e) {
                // Anti 500: kalau ada error di rule, jangan jatuhin panel
                Log::warning('[DezzProtect] pre-block rule failed: ' . $e->getMessage(), [
                    'path' => $path,
                    'method' => $method,
                ]);
            }

            // ======= LANJUT REQUEST =======
            $response = $next($request);

            // ======= AUDIT LOG (sesudah response) =======
            try {
                $status = method_exists($response, 'getStatusCode') ? (int) $response->getStatusCode() : 200;
                $ua = substr((string) $request->userAgent(), 0, 255);

                // Log ke Activity (kalau Activity gagal, aman karena try/catch)
                Activity::event('dezz:app_api.request')
                    ->property('method', $method)
                    ->property('path', $path)
                    ->property('status', $status)
                    ->property('ip', $ip)
                    ->property('user_agent', $ua)
                    ->property('actor_id', $user?->id)
                    ->property('actor_email', $user?->email)
                    ->log();

            } catch (Throwable $e) {
                // Anti 500
                Log::warning('[DezzProtect] audit log failed: ' . $e->getMessage(), [
                    'path' => $path,
                    'method' => $method,
                ]);
            }

            return $response;
        });

        // Parse all the includes to use on this request.
        $input = $this->request->input('include', []);
        $input = is_array($input) ? $input : explode(',', $input);

        $includes = (new Collection($input))->map(function ($value) {
            return trim($value);
        })->filter()->toArray();

        $this->fractal->parseIncludes($includes);
        $this->fractal->limitRecursion(2);
    }

    /**
     * Perform dependency injection of certain classes needed for core functionality
     * without littering the constructors of classes that extend this abstract.
     */
    public function loadDependencies(Fractal $fractal, Request $request)
    {
        $this->fractal = $fractal;
        $this->request = $request;
    }

    /**
     * Log blocked attempt (anti 500).
     */
    private function logBlocked(Request $request, string $action, array $extra = []): void
    {
        try {
            $user = $request->user();
            $path = '/' . ltrim((string) $request->path(), '/');
            $method = strtoupper((string) $request->method());
            $ip = (string) $request->ip();
            $ua = substr((string) $request->userAgent(), 0, 255);

            $payload = array_merge([
                'action' => $action,
                'method' => $method,
                'path' => $path,
                'ip' => $ip,
                'user_agent' => $ua,
                'actor_id' => $user?->id,
                'actor_email' => $user?->email,
            ], $extra);

            Activity::event('dezz:app_api.blocked')
                ->property('data', $payload)
                ->log();
        } catch (Throwable $e) {
            Log::warning('[DezzProtect] blocked log failed: ' . $e->getMessage());
        }
    }

    /**
     * Return an HTTP/201 response for the API.
     */
    protected function returnAccepted(): Response
    {
        return new Response('', Response::HTTP_ACCEPTED);
    }

    /**
     * Return an HTTP/204 response for the API.
     */
    protected function returnNoContent(): Response
    {
        return new Response('', Response::HTTP_NO_CONTENT);
    }
}
EOF

echo ""
echo "🚀 Bikin Admin page: /admin/dezz-protect ..."
backup_file "$ADMIN_CONTROLLER"
backup_file "$ADMIN_VIEW"

write_file "$ADMIN_CONTROLLER" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;

class DezzProtectController extends Controller
{
    public function __construct(private ViewFactory $view)
    {
    }

    public function index(): View
    {
        $user = Auth::user();
        if (!$user || (int) $user->id !== 1) {
            abort(403, 'Protect Panel By Dezz: Access Denied');
        }

        // ActivityLog model ada di Pterodactyl; kalau beda versi, try/catch biar gak 500.
        $logs = [];
        try {
            $model = \Pterodactyl\Models\ActivityLog::query()
                ->where('event', 'like', 'dezz:%')
                ->orderByDesc('id')
                ->limit(200)
                ->get();

            $logs = $model->toArray();
        } catch (\Throwable $e) {
            $logs = [];
        }

        return $this->view->make('admin.dezz-protect.index', [
            'logs' => $logs,
        ]);
    }
}
EOF

write_file "$ADMIN_VIEW" <<'EOF'
@extends('layouts.admin')

@section('title')
    Protect Panel By Dezz
@endsection

@section('content-header')
    <h1>
        🛡️ Protect Panel By Dezz
        <small style="opacity:.75;">Audit & Lock (Application API)</small>
    </h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Protect Panel By Dezz</li>
    </ol>
@endsection

@section('content')
<style>
    .dezz-wrap {
        border-radius: 12px;
        padding: 18px;
        background: radial-gradient(circle at 20% 20%, rgba(255,0,0,.10), transparent 40%),
                    radial-gradient(circle at 80% 10%, rgba(255,255,255,.08), transparent 45%),
                    linear-gradient(135deg, rgba(10,10,10,.95), rgba(20,0,0,.85));
        border: 1px solid rgba(255,0,0,.25);
        box-shadow: 0 10px 30px rgba(0,0,0,.35);
        position: relative;
        overflow: hidden;
    }
    .dezz-wm {
        position: absolute;
        right: -20px;
        bottom: -10px;
        font-size: 40px;
        font-weight: 900;
        letter-spacing: 2px;
        opacity: .12;
        transform: rotate(-8deg);
        user-select: none;
        pointer-events: none;
        text-transform: uppercase;
        color: #ff2a2a;
        text-shadow: 0 0 12px rgba(255,0,0,.25);
    }
    .dezz-badge {
        display: inline-flex;
        gap: 10px;
        align-items: center;
        padding: 10px 12px;
        border-radius: 10px;
        border: 1px solid rgba(255,0,0,.25);
        background: rgba(0,0,0,.35);
        margin-bottom: 14px;
    }
    .dezz-dot {
        width: 10px;
        height: 10px;
        border-radius: 50%;
        background: #ff2a2a;
        box-shadow: 0 0 12px rgba(255,0,0,.65);
    }
    .dezz-title {
        font-weight: 800;
        letter-spacing: .5px;
    }
    .dezz-sub {
        opacity: .8;
        font-size: 12px;
    }
    .dezz-table {
        width: 100%;
        border-collapse: collapse;
        font-size: 12px;
        background: rgba(0,0,0,.25);
        border-radius: 10px;
        overflow: hidden;
    }
    .dezz-table th, .dezz-table td {
        padding: 10px 10px;
        border-bottom: 1px solid rgba(255,255,255,.06);
        vertical-align: top;
    }
    .dezz-table th {
        text-transform: uppercase;
        letter-spacing: 1px;
        font-size: 11px;
        background: rgba(255,0,0,.08);
    }
    .dezz-pill {
        display: inline-block;
        padding: 3px 8px;
        border-radius: 999px;
        border: 1px solid rgba(255,0,0,.25);
        background: rgba(0,0,0,.35);
        font-weight: 700;
    }
    .dezz-empty {
        padding: 14px;
        border-radius: 10px;
        border: 1px dashed rgba(255,0,0,.25);
        background: rgba(0,0,0,.25);
        opacity: .85;
    }
</style>

<div class="dezz-wrap">
    <div class="dezz-wm">Protect Panel By Dezz</div>

    <div class="dezz-badge">
        <div class="dezz-dot"></div>
        <div>
            <div class="dezz-title">AUDIT AKTIF</div>
            <div class="dezz-sub">Event: <span class="dezz-pill">dezz:app_api.request</span> / <span class="dezz-pill">dezz:app_api.blocked</span></div>
        </div>
    </div>

    @if (empty($logs))
        <div class="dezz-empty">
            Belum ada log (atau model ActivityLog beda versi). Yang penting: panel tidak error 500.
        </div>
    @else
        <table class="dezz-table">
            <thead>
                <tr>
                    <th style="width:80px;">ID</th>
                    <th style="width:180px;">Event</th>
                    <th style="width:160px;">Actor</th>
                    <th>Properties</th>
                    <th style="width:180px;">Waktu</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($logs as $row)
                    <tr>
                        <td>#{{ $row['id'] ?? '-' }}</td>
                        <td><span class="dezz-pill">{{ $row['event'] ?? '-' }}</span></td>
                        <td>
                            <div><b>ID:</b> {{ $row['actor_id'] ?? '-' }}</div>
                            <div style="opacity:.8;"><b>Email:</b> {{ data_get($row, 'properties.actor_email', '-') }}</div>
                        </td>
                        <td style="word-break: break-word;">
                            <pre style="margin:0;white-space:pre-wrap;background:transparent;border:none;color:inherit;">{{ json_encode($row['properties'] ?? [], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) }}</pre>
                        </td>
                        <td>{{ $row['created_at'] ?? '-' }}</td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    @endif
</div>
@endsection
EOF

echo ""
echo "🚀 Tambah route admin (tanpa Kernel.php)..."
backup_file "$ADMIN_ROUTES"

# Append route safely if not exists
if ! grep -q "admin\.dezz-protect" "$ADMIN_ROUTES"; then
  cat >> "$ADMIN_ROUTES" <<'EOF'

/**
 * 🛡️ Protect Panel By Dezz (Admin Page)
 */
Route::get('/dezz-protect', [\Pterodactyl\Http\Controllers\Admin\DezzProtectController::class, 'index'])
    ->name('admin.dezz-protect');

EOF
  echo "✅ Route ditambahkan ke: $ADMIN_ROUTES"
else
  echo "ℹ️ Route sudah ada, skip."
fi

echo ""
echo "✅ SELESAI!"
echo "🔒 Proteksi Application API aktif + anti 500 (pakai try/catch)."
echo "📌 Admin UI log: /admin/dezz-protect (HANYA Admin ID 1)"
echo "🏷️ Watermark: Protect Panel By Dezz"
echo ""
echo "⚠️ Setelah ini jalankan:"
echo "   cd /var/www/pterodactyl && php artisan route:clear && php artisan view:clear"
echo ""
