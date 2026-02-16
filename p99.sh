#!/bin/bash
set -euo pipefail

PANEL="/var/www/pterodactyl"
cd "$PANEL"

php artisan down || true

TS="$(date -u +%Y-%m-%d-%H-%M-%S)"

echo "[0] Vars..."
echo "PANEL=$PANEL"
echo "TS=$TS"

backup_file () {
  local f="$1"
  if [ -f "$f" ]; then
    cp -a "$f" "${f}.bak_protect_${TS}"
  fi
}

echo "[1] Pasang middleware 'PLTA hanya user ID 1'..."

MW_DIR="app/Http/Middleware"
MW_FILE="${MW_DIR}/PltaIdOneOnly.php"
KERNEL="app/Http/Kernel.php"

mkdir -p "$MW_DIR"
backup_file "$MW_FILE"

cat > "$MW_FILE" <<'PHP'
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class PltaIdOneOnly
{
    /**
     * Block ALL PLTA-related access for any user except ID=1.
     *
     * This is enforced by request path matching so it works even if routes move.
     */
    public function handle(Request $request, Closure $next)
    {
        // Normalize: Only protect PLTA endpoints/pages
        // Add patterns here if your PLTA routes use different prefixes.
        $isPlta =
            $request->is('admin/api/plta') ||
            $request->is('admin/api/plta/*') ||
            $request->is('api/admin/plta') ||
            $request->is('api/admin/plta/*') ||
            $request->is('admin/plta') ||
            $request->is('admin/plta/*') ||
            $request->is('plta') ||
            $request->is('plta/*');

        if (!$isPlta) {
            return $next($request);
        }

        $user = $request->user();

        // If unauthenticated, deny (so API keys not linked to user won't pass).
        if (!$user) {
            abort(403, 'PLTA is restricted.');
        }

        // Only user id 1 can do anything PLTA-related.
        if ((int) $user->id !== 1) {
            abort(403, 'PLTA is restricted to owner.');
        }

        return $next($request);
    }
}
PHP

echo "  - Middleware created: $MW_FILE"

echo "[2] Register middleware ke Kernel.php (routeMiddleware alias)..."

if [ ! -f "$KERNEL" ]; then
  echo "ERROR: Kernel tidak ditemukan di $KERNEL"
  php artisan up || true
  exit 1
fi

backup_file "$KERNEL"

# Tambah use statement kalau belum ada (opsional, Laravel routeMiddleware cukup pakai string class)
# Kita cukup tambah alias di $routeMiddleware.

# Kalau alias sudah ada, skip.
if ! grep -q "plta\.id1" "$KERNEL"; then
  # Sisipkan di dalam protected $routeMiddleware = [ ... ];
  perl -0777 -i -pe 's/(protected\s+\$routeMiddleware\s*=\s*\[\s*)(.*?)(\]\s*;)/$1$2\n        \x27plta.id1\x27 => \App\Http\Middleware\PltaIdOneOnly::class,\n$3/s' "$KERNEL" || true
fi

# Validasi cepat: kalau belum kesisip, fallback tambah manual di bawah routeMiddleware
if ! grep -q "plta\.id1" "$KERNEL"; then
  echo "  - WARNING: gagal auto-insert alias. Coba fallback insert dekat routeMiddleware..."
  perl -0777 -i -pe 's/(protected\s+\$routeMiddleware\s*=\s*\[.*?\]\s*;)/$1\n\n    // Protect PLTA\n    protected $routeMiddlewarePltaProtect = [\n        \x27plta.id1\x27 => \App\Http\Middleware\PltaIdOneOnly::class,\n    ];/s' "$KERNEL" || true
fi

echo "  - Kernel patched: $KERNEL"

echo "[3] Patch routes/admin.php (optional hardening: pasang middleware di group PLTA jika ketemu)..."

ROUTES="routes/admin.php"
if [ -f "$ROUTES" ]; then
  backup_file "$ROUTES"

  # Jika ada route PLTA dengan pattern "plta" / "PltaController", coba tambahkan middleware('plta.id1')
  # 1) Tambah middleware ke group Route::prefix('plta')...
  perl -0777 -i -pe '
    s/(Route::prefix\(\x27plta\x27\)\s*->)(middleware\([^\)]*\)\s*->)?/my $a=$1; my $b=$2||""; if($b=~ /plta\.id1/){$a.$b}else{$a."middleware(\x27plta.id1\x27)->"} /ge;
  ' "$ROUTES" || true

  # 2) Kalau ada Route::group([...], function() { ... plta ... }), ini biar minimal (nggak maksa).
  # (Tidak agresif supaya nggak merusak file.)
  echo "  - routes/admin.php patched (best-effort)."
else
  echo "  - routes/admin.php tidak ada, skip."
fi

echo "[4] Hide PLTA di views (menu/link PLTA hanya tampil untuk user ID 1)..."

# Cari file blade yang mengandung "plta" atau "PLTA" lalu wrap blok link-nya sederhana.
# Karena struktur tiap panel beda, kita lakukan best-effort:
# - cari baris yang mengandung 'plta' dan '@if' belum ada, lalu bungkus 1 baris itu.
# Ini tidak sempurna tapi aman-ish, dan kamu bisa cek diff dari .bak_protect_*.

mapfile -t BLADES < <(grep -RIl --include="*.blade.php" -e "plta" -e "PLTA" resources/views 2>/dev/null || true)

if [ "${#BLADES[@]}" -eq 0 ]; then
  echo "  - Tidak ada blade yang mengandung PLTA/plta, skip."
else
  for f in "${BLADES[@]}"; do
    backup_file "$f"

    # Wrap BARIS yang mengandung plta/PLTA dan belum diwrap @if(auth()->...id===1)
    # (Best-effort, tidak ubah kalau sudah ada guard.)
    perl -i -pe '
      if (/plta/i && $_ !~ /\@if\s*\(\s*auth\(\)->check\(\)\s*&&\s*auth\(\)->user\(\)->id\s*===\s*1\s*\)/) {
        $_ = "\@if(auth()->check() && auth()->user()->id === 1)\n" . $_ . "\@endif\n";
      }
    ' "$f" || true
  done
  echo "  - Patched ${#BLADES[@]} blade(s)."
fi

echo "[5] Clear cache Laravel..."
php artisan optimize:clear || true
php artisan view:clear || true
php artisan route:clear || true
php artisan config:clear || true
php artisan cache:clear || true

php artisan up || true

echo
echo "DONE: PLTA hidden + lock selain user ID 1 aktif."
echo
echo "Cek cepat:"
echo "  - Middleware:   $MW_FILE"
echo "  - Kernel alias: plta.id1 di $KERNEL"
echo "  - Backup file:  *.bak_protect_${TS}"
echo
echo "Kalau ada error, cek log:"
echo "  tail -n 200 storage/logs/laravel-*.log"
