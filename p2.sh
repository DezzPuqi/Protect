#!/bin/bash
set -euo pipefail

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php"
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
echo -e "${BOLD}${CYN}🚀 Memasang Proteksi UserController.php (anti hapus & anti ubah data user)${NC}"
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
cat > "$REMOTE_PATH" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\User;
use Pterodactyl\Models\Model;
use Illuminate\Support\Collection;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Spatie\QueryBuilder\QueryBuilder;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\Translation\Translator;
use Pterodactyl\Services\Users\UserUpdateService;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Users\UserCreationService;
use Pterodactyl\Services\Users\UserDeletionService;
use Pterodactyl\Http\Requests\Admin\UserFormRequest;
use Pterodactyl\Http\Requests\Admin\NewUserFormRequest;
use Pterodactyl\Contracts\Repository\UserRepositoryInterface;
class UserController extends Controller
{
    use AvailableLanguages;

    /**
     * UserController constructor.
     */
    public function __construct(
        protected AlertsMessageBag $alert,
        protected UserCreationService $creationService,
        protected UserDeletionService $deletionService,
        protected Translator $translator,
        protected UserUpdateService $updateService,
        protected UserRepositoryInterface $repository,
        protected ViewFactory $view
    ) {
    }

    /**
     * Display user index page.
     */
    public function index(Request $request): View
    {
        $users = QueryBuilder::for(
            User::query()->select('users.*')
                ->selectRaw('COUNT(DISTINCT(subusers.id)) as subuser_of_count')
                ->selectRaw('COUNT(DISTINCT(servers.id)) as servers_count')
                ->leftJoin('subusers', 'subusers.user_id', '=', 'users.id')
                ->leftJoin('servers', 'servers.owner_id', '=', 'users.id')
                ->groupBy('users.id')
        )
            ->allowedFilters(['username', 'email', 'uuid'])
            ->allowedSorts(['id', 'uuid'])
            ->paginate(50);

        return $this->view->make('admin.users.index', ['users' => $users]);
    }

    /**
     * Display new user page.
     */
    public function create(): View
    {
        return $this->view->make('admin.users.new', [
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * Display user view page.
     */
    public function view(User $user): View
    {
        return $this->view->make('admin.users.view', [
            'user' => $user,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * Delete a user from the system.
     *
     * @throws Exception
     * @throws PterodactylExceptionsDisplayException
     */
    public function delete(Request $request, User $user): RedirectResponse
    {
        // === FITUR TAMBAHAN: Proteksi hapus user ===
        if ($request->user()->id !== 1) {
            throw new DisplayException("❌ Hanya admin ID 1 yang dapat menghapus user lain!");
        }
        // ============================================

        if ($request->user()->id === $user->id) {
            throw new DisplayException($this->translator->get('admin/user.exceptions.user_has_servers'));
        }

        $this->deletionService->handle($user);

        return redirect()->route('admin.users');
    }

    /**
     * Create a user.
     *
     * @throws Exception
     * @throws Throwable
     */
    public function store(NewUserFormRequest $request): RedirectResponse
    {
        $user = $this->creationService->handle($request->normalize());
        $this->alert->success($this->translator->get('admin/user.notices.account_created'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    /**
     * Update a user on the system.
     *
     * @throws PterodactylExceptionsModelDataValidationException
     * @throws PterodactylExceptionsRepositoryRecordNotFoundException
     */
    public function update(UserFormRequest $request, User $user): RedirectResponse
    {
        // === FITUR TAMBAHAN: Proteksi ubah data penting ===
        $restrictedFields = ['email', 'first_name', 'last_name', 'password'];

        foreach ($restrictedFields as $field) {
            if ($request->filled($field) && $request->user()->id !== 1) {
                throw new DisplayException("⚠️ Data hanya bisa diubah oleh admin ID 1.");
            }
        }

        // Cegah turunkan level admin ke user biasa
        if ($user->root_admin && $request->user()->id !== 1) {
            throw new DisplayException("🚫 Tidak dapat menurunkan hak admin pengguna ini. Hanya ID 1 yang memiliki izin.");
        }
        // ====================================================

        $this->updateService
            ->setUserLevel(User::USER_LEVEL_ADMIN)
            ->handle($user, $request->normalize());

        $this->alert->success(trans('admin/user.notices.account_updated'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    /**
     * Get a JSON response of users on the system.
     */
    public function json(Request $request): Model|Collection
    {
        $users = QueryBuilder::for(User::query())->allowedFilters(['email'])->paginate(25);

        // Handle single user requests.
        if ($request->query('user_id')) {
            $user = User::query()->findOrFail($request->input('user_id'));
            $user->md5 = md5(strtolower($user->email));

            return $user;
        }

        return $users->map(function ($item) {
            $item->md5 = md5(strtolower($item->email));

            return $item;
        });
    }
}
EOF
ok "File ditulis: ${BOLD}${REMOTE_PATH}${NC}"

step "Set permission file..."
chmod 644 "$REMOTE_PATH"
ok "Permission: 644"

line
echo -e "${BOLD}${GRN}✅ Proteksi UserController.php berhasil dipasang!${NC}"
echo -e "${CYN}📂 Lokasi file:${NC} ${BOLD}${REMOTE_PATH}${NC}"
if [ -f "$BACKUP_PATH" ]; then
  echo -e "${CYN}🗂️ Backup file lama:${NC} ${BOLD}${BACKUP_PATH}${NC}"
else
  echo -e "${CYN}🗂️ Backup file lama:${NC} ${DIM}(tidak ada file sebelumnya)${NC}"
fi
line
