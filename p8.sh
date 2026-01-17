#!/bin/bash
set -euo pipefail

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"
TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

# =========================
# UI - Protect Panel By Dezz (NO EMOJI BIAR GA MAMPUS ENCODING)
# =========================
NC="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
RED="\033[31m"; GRN="\033[32m"; YLW="\033[33m"; BLU="\033[34m"; CYN="\033[36m"; WHT="\033[37m"
hr() { echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
ok()   { echo -e "${GRN}[OK]${NC} $*"; }
info() { echo -e "${CYN}[..]${NC} $*"; }
warn() { echo -e "${YLW}[!!]${NC} $*"; }
fail() { echo -e "${RED}[XX]${NC} $*"; }

banner() {
  clear 2>/dev/null || true
  echo -e "${RED}${BOLD}PROTECT PANEL By Dezz${NC}"
  echo -e "${DIM}SERVER CONTROLLER SHIELD (owner-only + activity log)${NC}"
  hr
}

spin() {
  local msg="$1"; shift
  local pid
  local s='|/-\'
  local i=0
  echo -ne "${BLU}${BOLD}${msg}${NC} "
  ("$@") >/dev/null 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i + 1) % 4 ))
    echo -ne "\b${s:$i:1}"
    sleep 0.08
  done
  wait "$pid"
  echo -ne "\b"
  echo -e " ${GRN}DONE${NC}"
}

on_error() {
  local code=$?
  echo
  fail "Installer gagal (exit code: $code)"
  echo -e "${DIM}Cek permission + pastiin path bener: ${REMOTE_PATH}${NC}"
  exit "$code"
}
trap on_error ERR

banner
info "Target   : ${BOLD}${REMOTE_PATH}${NC}"
info "Backup   : ${BOLD}${BACKUP_PATH}${NC}"
info "Time UTC : ${BOLD}${TIMESTAMP}${NC}"
hr

echo -e "${CYN}Memasang proteksi Anti Akses Server Controller...${NC}"

# Backup file lama jika ada
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

info "Menulis patch ServerController (SEREM + LOG Activity + AdminID1 bypass)..."
hr

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Pterodactyl\Models\Server;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Transformers\Api\Client\ServerTransformer;
use Pterodactyl\Services\Servers\GetUserPermissionsService;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Http\Requests\Api\Client\Servers\GetServerRequest;

class ServerController extends ClientApiController
{
    /**
     * ServerController constructor.
     */
    public function __construct(private GetUserPermissionsService $permissionsService)
    {
        parent::__construct();
    }

    /**
     * Protect Panel By Dezz:
     * - Admin ID 1: bebas akses semua server.
     * - Selain itu: hanya owner server yang boleh lihat.
     * - Kalau ada yang coba intip server orang -> BLOCK + Activity log pada server target.
     */
    private function enforceOwnerOnly(GetServerRequest $request, Server $server): void
    {
        $user = $request->user();

        if (!$user) {
            $this->denyJson('Unauthorized.', 401);
        }

        // Admin ID 1 bypass
        if ((int) $user->id === 1) {
            return;
        }

        $ownerId = $server->owner_id
            ?? $server->user_id
            ?? ($server->owner?->id ?? null)
            ?? ($server->user?->id ?? null);

        // Owner tidak jelas -> tetap block biar ga bolong
        if ($ownerId === null) {
            $this->logAttempt($request, $server, $user, 'Owner not detected');
            $this->denyJson('ACCESS DENIED: OWNER NOT DETECTED. (Protect Panel By Dezz)', 403);
        }

        // Bukan owner -> block + log
        if ((int) $ownerId !== (int) $user->id) {
            $this->logAttempt($request, $server, $user, 'Foreign server access blocked');
            $this->denyJson(
                'ACCESS DENIED: THIS SERVER IS NOT YOURS. (Protect Panel By Dezz)',
                403
            );
        }
    }

    /**
     * Log ke Activity server target:
     * "User <username> baru saja mencoba mengakses server mu."
     */
    private function logAttempt(GetServerRequest $request, Server $server, $user, string $reason): void
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
            ->property('path', method_exists($request, 'path') ? $request->path() : null)
            ->property('reason', $reason)
            ->log(sprintf('User %s baru saja mencoba mengakses server mu.', $username));
    }

    /**
     * JSON deny biar panel kebaca rapi (bukan error HTML polos).
     * Frontend panel biasanya nampilin message ini di UI.
     */
    private function denyJson(string $message, int $status = 403): void
    {
        abort(
            response()->json([
                'object' => 'error',
                'attributes' => [
                    'status' => $status,
                    'message' => $message,
                    'wm' => 'Protect Panel By Dezz',
                    'threat' => [
                        'level' => 'HIGH',
                        'action' => 'BLOCKED',
                    ],
                ],
            ], $status)
        );
    }

    /**
     * Transform an individual server into a response that can be consumed by a client using the API.
     */
    public function index(GetServerRequest $request, Server $server): array
    {
        $this->enforceOwnerOnly($request, $server);

        return $this->fractal->item($server)
            ->transformWith($this->getTransformer(ServerTransformer::class))
            ->addMeta([
                'is_server_owner' => (int) $request->user()->id === (int) $server->owner_id,
                'user_permissions' => $this->permissionsService->handle($server, $request->user()),
            ])
            ->toArray();
    }
}
EOF

spin "Set permission file..." chmod 644 "$REMOTE_PATH"

hr
ok "Proteksi Anti Akses Server Controller berhasil dipasang!"
info "Lokasi : ${BOLD}${REMOTE_PATH}${NC}"
if [ -f "$BACKUP_PATH" ]; then
  info "Backup : ${BOLD}${BACKUP_PATH}${NC}"
else
  info "Backup : ${DIM}(tidak ada file sebelumnya)${NC}"
fi
info "Rules  : ${BOLD}Admin ID 1 bypass + Owner-only${NC}"
info "Log    : ${BOLD}Activity server target (server:shield.blocked)${NC}"
echo -e "${WHT}${BOLD}WM:${NC} ${CYN}Protect Panel By Dezz${NC}"
hr
