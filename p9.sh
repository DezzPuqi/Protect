#!/bin/bash
set -euo pipefail

REMOTE_PATH="/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

# =========================
# UI - Protect Panel By Dezz (serem)
# =========================
NC="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
RED="\033[31m"; GRN="\033[32m"; YLW="\033[33m"; BLU="\033[34m"; CYN="\033[36m"; WHT="\033[37m"
hr(){ echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
ok(){ echo -e "${GRN}[OK]${NC} $*"; }
info(){ echo -e "${CYN}[..]${NC} $*"; }
warn(){ echo -e "${YLW}[!!]${NC} $*"; }
fail(){ echo -e "${RED}[XX]${NC} $*"; }

banner() {
  clear 2>/dev/null || true
  echo -e "${RED}${BOLD}PROTECT PANEL By Dezz${NC}"
  echo -e "${DIM}DETAILS MODIFICATION SHIELD (admin-1 only + activity log)${NC}"
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
info "Memasang proteksi Anti Modifikasi Server (SEREM + WM + log)..."
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

info "Menulis patch DetailsModificationService (Admin ID 1 only + Activity log)..."
hr

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Arr;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Traits\Services\ReturnsUpdatedModels;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;
use Pterodactyl\Exceptions\DisplayException;

class DetailsModificationService
{
    use ReturnsUpdatedModels;

    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $serverRepository
    ) {}

    /**
     * Update the details for a single server instance.
     *
     * 🔒 Protect Panel By Dezz:
     * - Hanya Admin ID 1 yang boleh ubah detail server.
     * - Kalau selain ID 1 coba ubah => BLOCK + Activity log + Log::warning.
     *
     * @throws \Throwable
     */
    public function handle(Server $server, array $data): Server
    {
        $user = Auth::user();

        // HARD BLOCK (lebih aman daripada abort() di service layer)
        if (!$user || (int) $user->id !== 1) {
            $this->logBlockedAttempt($server, $user, $data);

            // DisplayException biar panel/API dapet message yang jelas
            throw new DisplayException('⛔ ACCESS DENIED: ONLY ADMIN ID 1 CAN MODIFY SERVER DETAILS. (Protect Panel By Dezz)');
        }

        return $this->connection->transaction(function () use ($data, $server) {
            $oldOwner = $server->owner_id;

            $server->forceFill([
                'external_id' => Arr::get($data, 'external_id'),
                'owner_id' => Arr::get($data, 'owner_id'),
                'name' => Arr::get($data, 'name'),
                'description' => Arr::get($data, 'description') ?? '',
            ])->saveOrFail();

            // Jika owner berubah, revoke token lama
            if ((int) $server->owner_id !== (int) $oldOwner) {
                try {
                    $this->serverRepository->setServer($server)->revokeUserJTI($oldOwner);
                } catch (DaemonConnectionException $exception) {
                    // Wings offline => ignore
                    Log::warning($exception);
                }
            }

            return $server;
        });
    }

    /**
     * Catat percobaan modifikasi ilegal.
     * Owner server bisa lihat di Activity, admin bisa lihat di log.
     */
    private function logBlockedAttempt(Server $server, $user, array $data): void
    {
        $who = 'Unknown';
        $whoId = null;

        if ($user) {
            $whoId = $user->id ?? null;
            $who = $user->username
                ?? trim(($user->first_name ?? '') . ' ' . ($user->last_name ?? ''))
                ?? $user->email
                ?? ('User#' . ($whoId ?? 'Unknown'));
        }

        // Activity attach ke server
        try {
            Activity::event('server:details.modify.blocked')
                ->subject($server)
                ->property('attempted_by_id', $whoId)
                ->property('attempted_by', $who)
                ->property('payload_keys', array_keys($data))
                ->property('wm', 'Protect Panel By Dezz')
                ->log(sprintf('User %s mencoba memodifikasi detail server tanpa izin.', $who));
        } catch (\Throwable $e) {
            // kalau activity gagal, jangan bikin fatal
        }

        // Server-side log buat admin forensic
        Log::warning('Protect Panel By Dezz: blocked server details modification attempt.', [
            'server_id' => $server->id ?? null,
            'server_uuid' => $server->uuid ?? null,
            'attempted_by_id' => $whoId,
            'attempted_by' => $who,
            'payload_keys' => array_keys($data),
            'wm' => 'Protect Panel By Dezz',
        ]);
    }
}
EOF

spin "Set permission file..." chmod 644 "$REMOTE_PATH"

hr
ok "Proteksi Anti Modifikasi Server berhasil dipasang!"
info "Lokasi : ${BOLD}${REMOTE_PATH}${NC}"
if [ -f "$BACKUP_PATH" ]; then
  info "Backup : ${BOLD}${BACKUP_PATH}${NC}"
else
  info "Backup : ${DIM}(tidak ada file sebelumnya)${NC}"
fi
info "Rules  : ${BOLD}Only Admin ID 1${NC}"
info "Log    : ${BOLD}Activity(server:details.modify.blocked) + Laravel log warning${NC}"
echo -e "${WHT}${BOLD}WM:${NC} ${CYN}Protect Panel By Dezz${NC}"
hr
