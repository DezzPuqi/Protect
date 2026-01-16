#!/bin/bash
set -euo pipefail

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php"
TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

# =========================
# UI - Protect Panel By Dezz (serem)
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
  echo -e "${RED}${BOLD}    <h1>🩸 FILE ACCESS SHIELD: ENABLED</h1>${NC}"
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
  echo -e "${DIM}Pastikan jalan sebagai root / permission tulis ke path target.${NC}"
  exit "$code"
}
trap on_error ERR

banner
info "Mode     : Installer"
info "Target   : ${BOLD}${REMOTE_PATH}${NC}"
info "Backup   : ${BOLD}${BACKUP_PATH}${NC}"
info "Time UTC : ${BOLD}${TIMESTAMP}${NC}"
hr
info "🚀 Memasang proteksi Anti Akses Server File Controller + Activity Log (intip detector)"
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

info "Menulis patch proteksi + log activity..."
hr

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Carbon\CarbonImmutable;
use Illuminate\Http\Response;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Pterodactyl\Models\Server;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Services\Nodes\NodeJWTService;
use Pterodactyl\Repositories\Wings\DaemonFileRepository;
use Pterodactyl\Transformers\Api\Client\FileObjectTransformer;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CopyFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\PullFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\ListFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\ChmodFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\DeleteFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\RenameFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CreateFolderRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CompressFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\DecompressFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\GetFileContentsRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\WriteFileContentRequest;

class FileController extends ClientApiController
{
    public function __construct(
        private NodeJWTService $jwtService,
        private DaemonFileRepository $fileRepository
    ) {
        parent::__construct();
    }

    /**
     * 🔒 Proteksi + Activity Log:
     * - Admin (ID 1) bebas.
     * - User biasa hanya bisa akses server miliknya.
     * - Kalau coba intip server orang: catat Activity pada server itu.
     */
    private function checkServerAccess(Request $request, Server $server): void
    {
        $user = $request->user();

        if (!$user) {
            // API client biasanya selalu ada user, tapi kalau tidak ada ya tolak.
            $this->logUnauthorizedAttempt($request, $server, null);
            $this->denyJson('Unauthorized.');
        }

        // Admin (user id = 1) bebas akses semua
        if ((int) $user->id === 1) {
            return;
        }

        // Jika server bukan milik user, tolak akses + log
        if ((int) $server->owner_id !== (int) $user->id) {
            $this->logUnauthorizedAttempt($request, $server, $user);
            $this->denyJson('Anda tidak memiliki akses ke server ini.');
        }
    }

    /**
     * Catat activity pada server agar owner bisa lihat:
     * "User <username> baru saja mencoba mengakses server mu"
     */
    private function logUnauthorizedAttempt(Request $request, Server $server, $user = null): void
    {
        $username = 'Unknown';
        $userId = null;

        if ($user) {
            $userId = $user->id ?? null;
            // fallback username (tergantung versi panel)
            $username = $user->username
                ?? trim(($user->first_name ?? '') . ' ' . ($user->last_name ?? ''))
                ?? $user->email
                ?? ('User#' . ($userId ?? 'Unknown'));
        }

        $path = $request->path();
        $ip = method_exists($request, 'ip') ? $request->ip() : null;

        // Event di-attach ke server -> owner bisa lihat di Activity server.
        Activity::event('server:file.unauthorized')
            ->subject($server)
            ->property('attempted_by_id', $userId)
            ->property('attempted_by', $username)
            ->property('ip', $ip)
            ->property('path', $path)
            ->log(sprintf('User %s baru saja mencoba mengakses server mu.', $username));
    }

    /**
     * Response JSON 403 (biar API tidak dapat HTML).
     */
    private function denyJson(string $message): void
    {
        abort(
            response()->json([
                'object' => 'error',
                'attributes' => [
                    'status' => 403,
                    'message' => $message,
                ],
            ], 403)
        );
    }

    public function directory(ListFilesRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);

        $contents = $this->fileRepository
            ->setServer($server)
            ->getDirectory($request->get('directory') ?? '/');

        return $this->fractal->collection($contents)
            ->transformWith($this->getTransformer(FileObjectTransformer::class))
            ->toArray();
    }

    public function contents(GetFileContentsRequest $request, Server $server): Response
    {
        $this->checkServerAccess($request, $server);

        $response = $this->fileRepository->setServer($server)->getContent(
            $request->get('file'),
            config('pterodactyl.files.max_edit_size')
        );

        Activity::event('server:file.read')->property('file', $request->get('file'))->log();

        return new Response($response, Response::HTTP_OK, ['Content-Type' => 'text/plain']);
    }

    public function download(GetFileContentsRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);

        $token = $this->jwtService
            ->setExpiresAt(CarbonImmutable::now()->addMinutes(15))
            ->setUser($request->user())
            ->setClaims([
                'file_path' => rawurldecode($request->get('file')),
                'server_uuid' => $server->uuid,
            ])
            ->handle($server->node, $request->user()->id . $server->uuid);

        Activity::event('server:file.download')->property('file', $request->get('file'))->log();

        return [
            'object' => 'signed_url',
            'attributes' => [
                'url' => sprintf(
                    '%s/download/file?token=%s',
                    $server->node->getConnectionAddress(),
                    $token->toString()
                ),
            ],
        ];
    }

    public function write(WriteFileContentRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository->setServer($server)->putContent($request->get('file'), $request->getContent());

        Activity::event('server:file.write')->property('file', $request->get('file'))->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function create(CreateFolderRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository
            ->setServer($server)
            ->createDirectory($request->input('name'), $request->input('root', '/'));

        Activity::event('server:file.create-directory')
            ->property('name', $request->input('name'))
            ->property('directory', $request->input('root'))
            ->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function rename(RenameFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository
            ->setServer($server)
            ->renameFiles($request->input('root'), $request->input('files'));

        Activity::event('server:file.rename')
            ->property('directory', $request->input('root'))
            ->property('files', $request->input('files'))
            ->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function copy(CopyFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository
            ->setServer($server)
            ->copyFile($request->input('location'));

        Activity::event('server:file.copy')->property('file', $request->input('location'))->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function compress(CompressFilesRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);

        $file = $this->fileRepository->setServer($server)->compressFiles(
            $request->input('root'),
            $request->input('files')
        );

        Activity::event('server:file.compress')
            ->property('directory', $request->input('root'))
            ->property('files', $request->input('files'))
            ->log();

        return $this->fractal->item($file)
            ->transformWith($this->getTransformer(FileObjectTransformer::class))
            ->toArray();
    }

    public function decompress(DecompressFilesRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        set_time_limit(300);

        $this->fileRepository->setServer($server)->decompressFile(
            $request->input('root'),
            $request->input('file')
        );

        Activity::event('server:file.decompress')
            ->property('directory', $request->input('root'))
            ->property('files', $request->input('file'))
            ->log();

        return new JsonResponse([], JsonResponse::HTTP_NO_CONTENT);
    }

    public function delete(DeleteFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository->setServer($server)->deleteFiles(
            $request->input('root'),
            $request->input('files')
        );

        Activity::event('server:file.delete')
            ->property('directory', $request->input('root'))
            ->property('files', $request->input('files'))
            ->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function chmod(ChmodFilesRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository->setServer($server)->chmodFiles(
            $request->input('root'),
            $request->input('files')
        );

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function pull(PullFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);

        $this->fileRepository->setServer($server)->pull(
            $request->input('url'),
            $request->input('directory'),
            $request->safe(['filename', 'use_header', 'foreground'])
        );

        Activity::event('server:file.pull')
            ->property('directory', $request->input('directory'))
            ->property('url', $request->input('url'))
            ->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }
}
EOF

spin "Set permission file..." chmod 644 "$REMOTE_PATH"

hr
ok "Proteksi Anti Akses Server File Controller berhasil dipasang!"
info "Lokasi : ${BOLD}${REMOTE_PATH}${NC}"
if [ -f "$BACKUP_PATH" ]; then
  info "Backup : ${BOLD}${BACKUP_PATH}${NC}"
else
  info "Backup : ${DIM}(tidak ada file sebelumnya)${NC}"
fi
info "Log    : ${BOLD}Activity akan mencatat percobaan intip${NC} (${DIM}server:file.unauthorized${NC})"
echo -e "${WHT}${BOLD}WM:${NC} ${CYN}Protect Panel By Dezz${NC}"
hr
