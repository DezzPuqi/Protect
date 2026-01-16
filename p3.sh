#!/bin/bash
set -euo pipefail

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"
TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

# ====== UI (tampilan doang, struktur install tetap mirip) ======
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
  echo -e "${DIM}Hint:${NC} jalankan sebagai root / punya izin tulis ke path target."
  exit "$code"
}
trap on_error ERR

clear 2>/dev/null || true
echo -e "${BOLD}${CYN}🚀 Memasang Proteksi Anti Akses Location (LocationController.php)${NC}"
line
info "Target file : ${BOLD}${REMOTE_PATH}${NC}"
info "Timestamp   : ${BOLD}${TIMESTAMP}${NC}"
line

step "Cek file lama & backup (kalau ada)..."
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
ok "File ditulis: ${BOLD}${REMOTE_PATH}${NC}"

step "Set permission file..."
chmod 644 "$REMOTE_PATH"
ok "Permission: 644"

line
echo -e "${BOLD}${GRN}✅ Proteksi Anti Akses Location berhasil dipasang!${NC}"
echo -e "${CYN}📂 Lokasi file:${NC} ${BOLD}${REMOTE_PATH}${NC}"
if [ -f "$BACKUP_PATH" ]; then
  echo -e "${CYN}🗂️ Backup file lama:${NC} ${BOLD}${BACKUP_PATH}${NC}"
else
  echo -e "${CYN}🗂️ Backup file lama:${NC} ${DIM}(tidak ada file sebelumnya)${NC}"
fi
echo -e "${CYN}🔒 Rules:${NC} ${BOLD}Hanya Admin (ID 1) yang bisa akses fitur Location.${NC}"
line
