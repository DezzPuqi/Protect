#!/bin/bash
set -euo pipefail

# ==========================================================
# Protect Panel By Dezz - FIX 500 + Owner Only (NO KERNEL PATCH)
# - Restore Kernel/routes backup TERAKHIR (kalau ada)
# - Pasang proteksi di controller via $this->middleware() (aman)
# - Log Activity saat ada yg coba intip server orang
# - Admin ID 1: bebas
# ==========================================================

PTERO_BASE="/var/www/pterodactyl"
TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"

SERVER_CTRL="${PTERO_BASE}/app/Http/Controllers/Api/Client/Servers/ServerController.php"
WS_CTRL="${PTERO_BASE}/app/Http/Controllers/Api/Client/Servers/WebsocketController.php"
FILE_CTRL="${PTERO_BASE}/app/Http/Controllers/Api/Client/Servers/FileController.php"

KERNEL_PATH="${PTERO_BASE}/app/Http/Kernel.php"
ROUTES_PATH="${PTERO_BASE}/routes/api-client.php"

# =========================
# UI - Protect Panel By Dezz
# =========================
NC="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
RED="\033[31m"; GRN="\033[32m"; YLW="\033[33m"; BLU="\033[34m"; CYN="\033[36m"; WHT="\033[37m"

hr() { echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
ok()   { echo -e "${GRN}✔${NC} $*"; }
info() { echo -e "${CYN}➜${NC} $*"; }
warn() { echo -e "${YLW}!${NC} $*"; }
fail() { echo -e "${RED}✖${NC} $*"; }

banner() {
  clear 2>/dev/null || true
  echo -e "${RED}${BOLD}<html>${NC}"
  echo -e "${RED}${BOLD}  <head><title>PROTECT PANEL</title></head>${NC}"
  echo -e "${RED}${BOLD}  <body>${NC}"
  echo -e "${RED}${BOLD}    <h1>🩸 OWNER SHIELD (NO KERNEL PATCH) — FIX 500</h1>${NC}"
  echo -e "${WHT}${BOLD}    <p>WM: Protect Panel By Dezz</p>${NC}"
  echo -e "${RED}${BOLD}  </body>${NC}"
  echo -e "${RED}${BOLD}</html>${NC}"
  hr
}

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
  echo -e "${DIM}Cek permission & pastiin path ptero bener: ${PTERO_BASE}${NC}"
  exit "$code"
}
trap on_error ERR

restore_latest() {
  local f="$1"
  local latest
  latest="$(ls -1t "${f}.bak_"* 2>/dev/null | head -n 1 || true)"
  if [ -n "${latest}" ] && [ -f "${latest}" ]; then
    mv "$latest" "$f"
    ok "Restore: ${DIM}${f}${NC} (dari $(basename "$latest"))"
  else
    warn "Restore skip (backup gak ketemu): $(basename "$f")"
  fi
}

backup_if_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    mv "$f" "${f}.bak_${TIMESTAMP}"
    ok "Backup: ${DIM}${f}.bak_${TIMESTAMP}${NC}"
  else
    warn "File tidak ada, akan dibuat: $(basename "$f")"
  fi
}

banner
info "Base     : ${BOLD}${PTERO_BASE}${NC}"
info "Time UTC : ${BOLD}${TIMESTAMP}${NC}"
hr

# 1) RESTORE kernel/routes (buat hilangin 500 dari patch sebelumnya)
info "Step 1/3: Restore Kernel.php & routes/api-client.php (kalau ada backup terakhir)..."
restore_latest "$KERNEL_PATH"
restore_latest "$ROUTES_PATH"
hr

# 2) BACKUP controller yang mau di-patch
info "Step 2/3: Backup controller target..."
backup_if_exists "$SERVER_CTRL"
backup_if_exists "$WS_CTRL"
backup_if_exists "$FILE_CTRL"
hr

spin "Menyiapkan direktori controller..." mkdir -p "$(dirname "$SERVER_CTRL")"
chmod 755 "$(dirname "$SERVER_CTRL")"

info "Step 3/3: Menulis controller proteksi (NO kernel patch)..."
hr

# =========================
# ServerController.php
# Blocks "buka server" dari awal
# =========================
cat > "$SERVER_CTRL" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Models\Server;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Transformers\Api\Client\ServerTransformer;

class ServerController extends ClientApiController
{
    public function __construct()
    {
        parent::__construct();

        // 🔒 HARD LOCK (tanpa Kernel): admin 1 bebas, selain itu owner-only
        $this->middleware(function ($request, $next) {
            $user = $request->user();

            if (!$user) {
                return $this->denyJson(401, 'Unauthorized.');
            }

            if ((int) $user->id === 1) {
                return $next($request);
            }

            $server = $request->route('server');
            if (!$server instanceof Server) {
                return $this->denyJson(403, 'Access denied.');
            }

            $ownerId = $server->owner_id
                ?? $server->user_id
                ?? ($server->owner?->id ?? null)
                ?? ($server->user?->id ?? null);

            if ($ownerId === null || (int) $ownerId !== (int) $user->id) {
                $this->logAttempt($request, $server, $user, 'Open server blocked');
                return $this->denyJson(403, '⛔ Access denied (Protect Panel By Dezz).');
            }

            return $next($request);
        });
    }

    private function denyJson(int $status, string $message)
    {
        return response()->json([
            'object' => 'error',
            'attributes' => [
                'status' => $status,
                'message' => $message,
            ],
        ], $status);
    }

    private function logAttempt(Request $request, Server $server, $user, string $reason): void
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
            ->property('path', $request->path())
            ->property('reason', $reason)
            ->log(sprintf('User %s baru saja mencoba mengakses server mu.', $username));
    }

    /**
     * GET /api/client/servers/{server}
     */
    public function __invoke(Request $request, Server $server): array
    {
        return $this->fractal->item($server)
            ->transformWith($this->getTransformer(ServerTransformer::class))
            ->toArray();
    }
}
EOF

# =========================
# WebsocketController.php
# Blocks console token/websocket (jadi console gak kebuka)
# =========================
cat > "$WS_CTRL" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Illuminate\Http\Request;
use Pterodactyl\Models\Server;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Services\Nodes\NodeJWTService;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;

class WebsocketController extends ClientApiController
{
    public function __construct(private NodeJWTService $jwtService)
    {
        parent::__construct();

        // 🔒 HARD LOCK (tanpa Kernel): admin 1 bebas, selain itu owner-only
        $this->middleware(function ($request, $next) {
            $user = $request->user();

            if (!$user) {
                return $this->denyJson(401, 'Unauthorized.');
            }

            if ((int) $user->id === 1) {
                return $next($request);
            }

            $server = $request->route('server');
            if (!$server instanceof Server) {
                return $this->denyJson(403, 'Access denied.');
            }

            $ownerId = $server->owner_id
                ?? $server->user_id
                ?? ($server->owner?->id ?? null)
                ?? ($server->user?->id ?? null);

            if ($ownerId === null || (int) $ownerId !== (int) $user->id) {
                $this->logAttempt($request, $server, $user, 'Websocket/console blocked');
                return $this->denyJson(403, '⛔ Access denied (Protect Panel By Dezz).');
            }

            return $next($request);
        });
    }

    private function denyJson(int $status, string $message)
    {
        return response()->json([
            'object' => 'error',
            'attributes' => [
                'status' => $status,
                'message' => $message,
            ],
        ], $status);
    }

    private function logAttempt(Request $request, Server $server, $user, string $reason): void
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
            ->property('path', $request->path())
            ->property('reason', $reason)
            ->log(sprintf('User %s baru saja mencoba mengakses server mu.', $username));
    }

    /**
     * GET /api/client/servers/{server}/websocket
     */
    public function __invoke(Request $request, Server $server): array
    {
        $token = $this->jwtService->handle($server->node, $request->user()->id . $server->uuid);

        Activity::event('server:console.token')->log();

        return [
            'data' => [
                'token' => $token->toString(),
                'socket' => $server->node->getConnectionAddress() . '/api/servers/' . $server->uuid . '/ws',
            ],
        ];
    }
}
EOF

# =========================
# FileController.php
# Blocks file API (owner-only + log)
# =========================
cat > "$FILE_CTRL" <<'EOF'
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

        // 🔒 HARD LOCK (tanpa Kernel): admin 1 bebas, selain itu owner-only
        $this->middleware(function ($request, $next) {
            $user = $request->user();

            if (!$user) {
                return $this->denyJson(401, 'Unauthorized.');
            }

            if ((int) $user->id === 1) {
                return $next($request);
            }

            $server = $request->route('server');
            if (!$server instanceof Server) {
                return $this->denyJson(403, 'Access denied.');
            }

            $ownerId = $server->owner_id
                ?? $server->user_id
                ?? ($server->owner?->id ?? null)
                ?? ($server->user?->id ?? null);

            if ($ownerId === null || (int) $ownerId !== (int) $user->id) {
                $this->logAttempt($request, $server, $user, 'Files blocked');
                return $this->denyJson(403, '⛔ Access denied (Protect Panel By Dezz).');
            }

            return $next($request);
        });
    }

    private function denyJson(int $status, string $message)
    {
        return response()->json([
            'object' => 'error',
            'attributes' => [
                'status' => $status,
                'message' => $message,
            ],
        ], $status);
    }

    private function logAttempt(Request $request, Server $server, $user, string $reason): void
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
            ->property('path', $request->path())
            ->property('reason', $reason)
            ->log(sprintf('User %s baru saja mencoba mengakses server mu.', $username));
    }

    public function directory(ListFilesRequest $request, Server $server): array
    {
        $contents = $this->fileRepository
            ->setServer($server)
            ->getDirectory($request->get('directory') ?? '/');

        return $this->fractal->collection($contents)
            ->transformWith($this->getTransformer(FileObjectTransformer::class))
            ->toArray();
    }

    public function contents(GetFileContentsRequest $request, Server $server): Response
    {
        $response = $this->fileRepository->setServer($server)->getContent(
            $request->get('file'),
            config('pterodactyl.files.max_edit_size')
        );

        Activity::event('server:file.read')->property('file', $request->get('file'))->log();

        return new Response($response, Response::HTTP_OK, ['Content-Type' => 'text/plain']);
    }

    public function download(GetFileContentsRequest $request, Server $server): array
    {
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
        $this->fileRepository->setServer($server)->putContent($request->get('file'), $request->getContent());

        Activity::event('server:file.write')->property('file', $request->get('file'))->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function create(CreateFolderRequest $request, Server $server): JsonResponse
    {
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
        $this->fileRepository
            ->setServer($server)
            ->copyFile($request->input('location'));

        Activity::event('server:file.copy')->property('file', $request->input('location'))->log();

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function compress(CompressFilesRequest $request, Server $server): array
    {
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
        $this->fileRepository->setServer($server)->chmodFiles(
            $request->input('root'),
            $request->input('files')
        );

        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function pull(PullFileRequest $request, Server $server): JsonResponse
    {
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

chmod 644 "$SERVER_CTRL" "$WS_CTRL" "$FILE_CTRL"

hr
ok "✅ FIX selesai!"
info "Protect: ${BOLD}langsung keblok pas buka server orang (ServerController)${NC}"
info "Console: ${BOLD}keblok (WebsocketController)${NC}"
info "Files  : ${BOLD}keblok (FileController)${NC}"
info "Log    : ${BOLD}Activity server target${NC} -> 'User <username> baru saja mencoba mengakses server mu.'"
echo -e "${WHT}${BOLD}WM:${NC} ${CYN}Protect Panel By Dezz${NC}"
hr
