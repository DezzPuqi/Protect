#!/bin/bash
set -euo pipefail

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"
TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

# =========================
# UI - Protect Panel By Dezz
# =========================
NC="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
RED="\033[31m"
GRN="\033[32m"
YLW="\033[33m"
BLU="\033[34m"
CYN="\033[36m"
WHT="\033[37m"

banner() {
  clear 2>/dev/null || true
  echo -e "${CYN}${BOLD}"
  echo "██████╗ ██████╗  ██████╗ ████████╗███████╗ ██████╗████████╗"
  echo "██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝"
  echo "██████╔╝██████╔╝██║   ██║   ██║   █████╗  ██║        ██║   "
  echo "██╔═══╝ ██╔══██╗██║   ██║   ██║   ██╔══╝  ██║        ██║   "
  echo "██║     ██║  ██║╚██████╔╝   ██║   ███████╗╚██████╗   ██║   "
  echo "╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝ ╚═════╝   ╚═╝   "
  echo -e "${NC}"
  echo -e "${WHT}${BOLD}Protect Panel By Dezz${NC}"
  echo -e "${DIM}------------------------------------------------------------${NC}"
}

ok()    { echo -e "${GRN}✔${NC} $*"; }
info()  { echo -e "${CYN}➜${NC} $*"; }
warn()  { echo -e "${YLW}!${NC} $*"; }
fail()  { echo -e "${RED}✖${NC} $*"; }

spinner_run() {
  # usage: spinner_run "text..." command...
  local msg="$1"; shift
  local pid
  local spin='|/-\'
  local i=0

  echo -ne "${CYN}⏳${NC} ${msg} "
  ("$@") >/dev/null 2>&1 &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i + 1) % 4 ))
    echo -ne "\b${spin:$i:1}"
    sleep 0.08
  done

  wait "$pid"
  echo -ne "\b"
  echo -e " ${GRN}DONE${NC}"
}

on_error() {
  local code=$?
  echo
  fail "Gagal (exit code: $code)"
  echo -e "${DIM}Cek permission & pastikan path Pterodactyl bener.${NC}"
  exit "$code"
}
trap on_error ERR

banner
info "Mode     : ${BOLD}Installer${NC}"
info "Target   : ${BOLD}${REMOTE_PATH}${NC}"
info "Backup   : ${BOLD}${BACKUP_PATH}${NC}"
info "Time(UTC): ${BOLD}${TIMESTAMP}${NC}"
echo -e "${DIM}------------------------------------------------------------${NC}"

# Backup file lama jika ada
if [ -f "$REMOTE_PATH" ]; then
  spinner_run "Membuat backup file lama..." mv "$REMOTE_PATH" "$BACKUP_PATH"
  ok "Backup dibuat: ${BOLD}${BACKUP_PATH}${NC}"
else
  warn "File lama tidak ditemukan, skip backup."
fi

spinner_run "Menyiapkan direktori target..." mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"
ok "Direktori siap: $(dirname "$REMOTE_PATH")"

# Tulis file
echo -e "${CYN}📝${NC} Menulis patch proteksi..."
cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Location;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Http\Requests\Admin\LocationFormRequest;
use Pterodactyl\Services\Locations\LocationUpdateService;
use Pterodactyl\Services\Locations\LocationCreationService;
use Pterodactyl\Services\Locations\LocationDeletionService;
use Pterodactyl\Contracts\Repository\LocationRepositoryInterface;

class LocationController extends Controller
{
    /**
     * LocationController constructor.
     */
    public function __construct(
        protected AlertsMessageBag $alert,
        protected LocationCreationService $creationService,
        protected LocationDeletionService $deletionService,
        protected LocationRepositoryInterface $repository,
        protected LocationUpdateService $updateService,
        protected ViewFactory $view
    ) {
    }

    /**
     * Return the location overview page.
     */
    public function index(): View
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'Akses ditolak');
        }

        return $this->view->make('admin.locations.index', [
            'locations' => $this->repository->getAllWithDetails(),
        ]);
    }

    /**
     * Return the location view page.
     *
     * @throws \Pterodactyl\Exceptions\Repository\RecordNotFoundException
     */
    public function view(int $id): View
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'BOCAH TOLOL NGINTIP NGINTIP ');
        }

        return $this->view->make('admin.locations.view', [
            'location' => $this->repository->getWithNodes($id),
        ]);
    }

    /**
     * Handle request to create new location.
     *
     * @throws \Throwable
     */
    public function create(LocationFormRequest $request): RedirectResponse
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'BOCAH TOLOL NGINTIP NGINTIP ');
        }

        $location = $this->creationService->handle($request->normalize());
        $this->alert->success('Location was created successfully.')->flash();

        return redirect()->route('admin.locations.view', $location->id);
    }

    /**
     * Handle request to update or delete location.
     *
     * @throws \Throwable
     */
    public function update(LocationFormRequest $request, Location $location): RedirectResponse
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'BOCAH TOLOL NGINTIP NGINTIP ');
        }

        if ($request->input('action') === 'delete') {
            return $this->delete($location);
        }

        $this->updateService->handle($location->id, $request->normalize());
        $this->alert->success('Location was updated successfully.')->flash();

        return redirect()->route('admin.locations.view', $location->id);
    }

    /**
     * Delete a location from the system.
     *
     * @throws \Exception
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
    public function delete(Location $location): RedirectResponse
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'BOCAH TOLOL NGINTIP NGINTIP ');
        }

        try {
            $this->deletionService->handle($location->id);
            return redirect()->route('admin.locations');
        } catch (DisplayException $ex) {
            $this->alert->danger($ex->getMessage())->flash();
        }

        return redirect()->route('admin.locations.view', $location->id);
    }
}
EOF

spinner_run "Set permission file..." chmod 644 "$REMOTE_PATH"

echo -e "${DIM}------------------------------------------------------------${NC}"
ok "Proteksi Anti Akses Location berhasil dipasang!"
info "Lokasi : ${BOLD}${REMOTE_PATH}${NC}"
if [ -f "$BACKUP_PATH" ]; then
  info "Backup : ${BOLD}${BACKUP_PATH}${NC}"
else
  info "Backup : ${DIM}(tidak ada file sebelumnya)${NC}"
fi
echo -e "${WHT}${BOLD}WM:${NC} ${CYN}Protect Panel By Dezz${NC}"
echo -e "${DIM}------------------------------------------------------------${NC}"
