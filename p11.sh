#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Http/Middleware/Api/Client/Server/AuthenticateServerAccess.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

red="\033[31m"; green="\033[32m"; yellow="\033[33m"; cyan="\033[36m"; nc="\033[0m"; bold="\033[1m"

clear
echo -e "${cyan}${bold}╔══════════════════════════════════════════════╗${nc}"
echo -e "${cyan}${bold}║            Protect Panel By Dezz             ║${nc}"
echo -e "${cyan}${bold}║      Client API Monitor CPU (ID 1 Only)      ║${nc}"
echo -e "${cyan}${bold}╚══════════════════════════════════════════════╝${nc}"
echo

echo -e "${yellow}[*] Memasang proteksi Client API monitor CPU/Status (ID 1 bisa pantau semua server)...${nc}"
echo -e "${yellow}[*] Target: ${REMOTE_PATH}${nc}"
echo

# Backup file lama jika ada
if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo -e "${green}[+] Backup dibuat: ${BACKUP_PATH}${nc}"
else
  echo -e "${yellow}[!] File belum ada, lanjut buat baru...${nc}"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Middleware\Api\Client\Server;

use Illuminate\Http\Request;
use Pterodactyl\Models\Server;
use Pterodactyl\Facades\Activity;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Pterodactyl\Exceptions\Http\Server\ServerStateConflictException;

class AuthenticateServerAccess
{
    /**
     * Routes that this middleware should not apply to if the user is an admin.
     */
    protected array $except = [
        'api:client:server.ws',
    ];

    /**
     * Authenticate that this server exists and is not suspended or marked as installing.
     */
    public function handle(Request $request, \Closure $next): mixed
    {
        /** @var \Pterodactyl\Models\User $user */
        $user = $request->user();
        $server = $request->route()->parameter('server');

        if (!$server instanceof Server) {
            throw new NotFoundHttpException(trans('exceptions.api.resource_not_found'));
        }

        /**
         * ✅ Dezz Monitor Mode:
         * User ID 1 boleh pantau resource/status SEMUA server via Client API,
         * tapi hanya untuk endpoint view + resources (read-only monitoring).
         *
         * Endpoint yang diizinkan:
         * - api:client:server.view        => GET /api/client/servers/{server}
         * - api:client:server.resources   => GET /api/client/servers/{server}/resources
         */
        if ($user && (int) $user->id === 1) {
            if ($request->routeIs('api:client:server.view') || $request->routeIs('api:client:server.resources')) {
                Activity::event('dezz:monitor.access')
                    ->subject($server)
                    ->property('route', optional($request->route())->getName())
                    ->property('path', '/' . ltrim($request->path(), '/'))
                    ->property('ip', $request->ip())
                    ->property('target_owner_id', (int) $server->owner_id)
                    ->log(sprintf(
                        'Protect Panel By Dezz — ID 1 monitor server [%s] milik user_id=%d',
                        $server->uuid,
                        (int) $server->owner_id
                    ));

                $request->attributes->set('server', $server);
                return $next($request);
            }
        }

        // Default rule Pterodactyl:
        // user harus owner, subuser, atau root_admin. (root_admin tetap berlaku normal)
        if ($user->id !== $server->owner_id && !$user->root_admin) {
            if (!$server->subusers->contains('user_id', $user->id)) {

                // 🔥 Log attempt "ngintip"
                Activity::event('dezz:intruder.attempt')
                    ->subject($server)
                    ->property('route', optional($request->route())->getName())
                    ->property('path', '/' . ltrim($request->path(), '/'))
                    ->property('method', $request->method())
                    ->property('ip', $request->ip())
                    ->property('actor_user_id', (int) $user->id)
                    ->property('actor_username', (string) ($user->username ?? 'unknown'))
                    ->property('target_owner_id', (int) $server->owner_id)
                    ->log(sprintf(
                        'Protect Panel By Dezz — %s (user_id=%d) mencoba akses server orang lain [%s]',
                        (string) ($user->username ?? 'unknown'),
                        (int) $user->id,
                        $server->uuid
                    ));

                // Biar ga bocor info server: balikin 404 (resource_not_found) seperti default ptero.
                throw new NotFoundHttpException(trans('exceptions.api.resource_not_found'));
            }
        }

        try {
            $server->validateCurrentState();
        } catch (ServerStateConflictException $exception) {
            if (!$request->routeIs('api:client:server.view')) {
                if (($server->isSuspended() || $server->node->isUnderMaintenance()) && !$request->routeIs('api:client:server.resources')) {
                    throw $exception;
                }

                if (!$user->root_admin || !$request->routeIs($this->except)) {
                    throw $exception;
                }
            }
        }

        $request->attributes->set('server', $server);

        return $next($request);
    }
}
EOF

chmod 644 "$REMOTE_PATH"

echo
echo -e "${cyan}${bold}╔══════════════════════════════════════════════╗${nc}"
echo -e "${cyan}${bold}║        ✅ Protect Panel By Dezz Installed     ║${nc}"
echo -e "${cyan}${bold}╚══════════════════════════════════════════════╝${nc}"
echo -e "${green}[+] File: ${REMOTE_PATH}${nc}"
echo -e "${green}[+] Backup: ${BACKUP_PATH}${nc}"
echo
echo -e "${yellow}RULE:${nc}"
echo -e "${yellow}- ID 1 boleh monitor semua server (view + resources)${nc}"
echo -e "${yellow}- Selain itu tetap normal (owner/subuser/root_admin)${nc}"
echo -e "${yellow}- Percobaan intip akan masuk Activity Log${nc}"
echo
echo -e "${green}Done.${nc}"
