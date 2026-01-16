#!/bin/bash
set -euo pipefail

# =========================
# Anti Delete Server Installer (Pterodactyl)
# Tampilan dibagusin, struktur tetap mirip
# =========================

REMOTE_PATH="/var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php"
TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

# ====== UI (tampilan) ======
NC="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GRN="\033[32m"
YLW="\033[33m"
BLU="\033[34m"
CYN="\033[36m"
DIM="\033[2m"

ok()    { echo -e "${GRN}✅${NC} $*"; }
info()  { echo -e "${CYN}ℹ️${NC}  $*"; }
warn()  { echo -e "${YLW}⚠️${NC}  $*"; }
fail()  { echo -e "${RED}❌${NC} $*"; }
step()  { echo -e "${BLU}➜${NC}  $*"; }
line()  { echo -e "${DIM}------------------------------------------------------------${NC}"; }

on_error() {
  local code=$?
  fail "Terjadi error di baris ${BASH_LINENO[0]} (exit code: $code)"
  echo -e "${DIM}Hint:${NC} pastikan path Pterodactyl benar & script dijalankan dengan akses yang cukup."
  exit "$code"
}
trap on_error ERR

clear 2>/dev/null || true
echo -e "${BOLD}${CYN}🚀 Memasang Proteksi Anti Delete Server (Pterodactyl)${NC}"
line
info "Target file : ${BOLD}${REMOTE_PATH}${NC}"
info "Timestamp   : ${BOLD}${TIMESTAMP}${NC}"
line

# ====== Proses ======
step "Cek file lama & buat backup (kalau ada)..."
if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  ok "Backup dibuat: ${BOLD}${BACKUP_PATH}${NC}"
else
  warn "File lama tidak ditemukan, skip backup."
fi

step "Pastikan direktori target ada & permission aman..."
mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
ok "Direktori siap: $(dirname "$REMOTE_PATH")"

step "Menulis file proteksi ke target..."
cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Exceptions\DisplayException;
use Illuminate\Http\Response;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Log;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Services\Databases\DatabaseManagementService;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class ServerDeletionService
{
    protected bool $force = false;

    /**
     * ServerDeletionService constructor.
     */
    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $daemonServerRepository,
        private DatabaseManagementService $databaseManagementService
    ) {
    }

    /**
     * Set if the server should be forcibly deleted from the panel (ignoring daemon errors) or not.
     */
    public function withForce(bool $bool = true): self
    {
        $this->force = $bool;
        return $this;
    }

    /**
     * Delete a server from the panel and remove any associated databases from hosts.
     *
     * @throws \Throwable
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
    public function handle(Server $server): void
    {
        $user = Auth::user();

        // 🔒 Proteksi:
        // - Admin ID = 1 boleh menghapus server siapa saja.
        // - Selain itu, user biasa hanya boleh menghapus server MILIKNYA SENDIRI.
        // - Jika owner tidak terdeteksi dan user bukan admin, tolak.
        if ($user) {
            if ($user->id !== 1) {
                // Fallback deteksi owner (beberapa field umum).
                $ownerId = $server->owner_id
                    ?? $server->user_id
                    ?? ($server->owner?->id ?? null)
                    ?? ($server->user?->id ?? null);

                if ($ownerId === null) {
                    throw new DisplayException('Akses ditolak: informasi pemilik server tidak tersedia.');
                }

                if ($ownerId !== $user->id) {
                    throw new DisplayException('❌Akses ditolak: Anda hanya dapat menghapus server milik Anda sendiri');
                }
            }
            // jika $user->id === 1, lanjutkan (super admin)
        }
        // Jika tidak ada $user (mis. CLI/background job), biarkan proses berjalan.

        try {
            $this->daemonServerRepository->setServer($server)->delete();
        } catch (DaemonConnectionException $exception) {
            // Abaikan error 404, tapi lempar error lain jika tidak mode force
            if (!$this->force && $exception->getStatusCode() !== Response::HTTP_NOT_FOUND) {
                throw $exception;
            }

            Log::warning($exception);
        }

        $this->connection->transaction(function () use ($server) {
            foreach ($server->databases as $database) {
                try {
                    $this->databaseManagementService->delete($database);
                } catch (\Exception $exception) {
                    if (!$this->force) {
                        throw $exception;
                    }

                    // Jika gagal delete database di host, tetap hapus dari panel
                    $database->delete();
                    Log::warning($exception);
                }
            }

            $server->delete();
        });
    }
}
EOF
ok "File ditulis: ${BOLD}${REMOTE_PATH}${NC}"

step "Set permission file..."
chmod 644 "$REMOTE_PATH"
ok "Permission: 644"

line
echo -e "${BOLD}${GRN}✅ Proteksi Anti Delete Server berhasil dipasang!${NC}"
echo -e "${CYN}📂 Lokasi file:${NC} ${BOLD}${REMOTE_PATH}${NC}"
if [ -f "$BACKUP_PATH" ]; then
  echo -e "${CYN}🗂️ Backup file lama:${NC} ${BOLD}${BACKUP_PATH}${NC}"
else
  echo -e "${CYN}🗂️ Backup file lama:${NC} ${DIM}(tidak ada file sebelumnya)${NC}"
fi
echo -e "${CYN}🔒 Rules:${NC} ${BOLD}Hanya Admin (ID 1) yang bisa hapus server orang lain.${NC}"
line
