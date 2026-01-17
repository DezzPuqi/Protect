#!/bin/bash
set -euo pipefail

PANEL_DIR="/var/www/pterodactyl"
LOGIN_VIEW="${PANEL_DIR}/resources/views/auth/login.blade.php"
TIMESTAMP="$(date -u +"%Y-%m-%d-%H-%M-%S")"
BACKUP="${LOGIN_VIEW}.bak_${TIMESTAMP}"

# ===== UI =====
NC="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
RED="\033[31m"; GRN="\033[32m"; YLW="\033[33m"; BLU="\033[34m"; CYN="\033[36m"; WHT="\033[37m"
hr() { echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
ok()   { echo -e "${GRN}✔${NC} $*"; }
info() { echo -e "${CYN}➜${NC} $*"; }
warn() { echo -e "${YLW}!${NC} $*"; }
fail() { echo -e "${RED}✖${NC} $*"; }

on_error() {
  local code=$?
  echo
  fail "Gagal (exit code: $code)"
  echo -e "${DIM}Cek path panel & permission.${NC}"
  exit "$code"
}
trap on_error ERR

clear 2>/dev/null || true
echo -e "${RED}${BOLD}<html>${NC}"
echo -e "${RED}${BOLD}  <body>${NC}"
echo -e "${RED}${BOLD}    <h1>⛔ LOGIN UI PATCH ENABLED</h1>${NC}"
echo -e "${WHT}${BOLD}    <p>WM: Protect Panel By Dezz</p>${NC}"
echo -e "${RED}${BOLD}  </body>${NC}"
echo -e "${RED}${BOLD}</html>${NC}"
hr

info "Panel Dir : ${BOLD}${PANEL_DIR}${NC}"
info "Target    : ${BOLD}${LOGIN_VIEW}${NC}"

if [ ! -d "$PANEL_DIR" ]; then
  fail "Folder panel tidak ditemukan: $PANEL_DIR"
  exit 1
fi

mkdir -p "$(dirname "$LOGIN_VIEW")"

# backup
if [ -f "$LOGIN_VIEW" ]; then
  cp -a "$LOGIN_VIEW" "$BACKUP"
  ok "Backup dibuat: ${BOLD}${BACKUP}${NC}"
else
  warn "File login.blade.php tidak ada, akan dibuat baru."
fi

hr
info "Menulis tampilan login baru (logo D, tanpa logo Pterodactyl)..."
hr

cat > "$LOGIN_VIEW" <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Sign in</title>

  <style>
    :root{
      --bg0:#07070a;
      --bg1:#0b0c14;
      --card:rgba(255,255,255,.06);
      --card2:rgba(255,255,255,.03);
      --line:rgba(255,255,255,.10);
      --text:#eaeaf2;
      --muted:rgba(234,234,242,.72);
      --shadow:rgba(0,0,0,.55);
      --danger:#ff4d4d;
      --ok:#40ffb5;
      --accentA:#ff0033;
      --accentB:#00a0ff;
      --focus:rgba(0,160,255,.35);
    }

    *{ box-sizing:border-box; }
    html,body{ height:100%; }
    body{
      margin:0;
      min-height:100vh;
      display:flex;
      align-items:center;
      justify-content:center;
      background:
        radial-gradient(800px 500px at 20% 20%, rgba(255,0,0,.18), transparent 60%),
        radial-gradient(900px 600px at 80% 80%, rgba(0,160,255,.14), transparent 60%),
        linear-gradient(180deg,var(--bg0),var(--bg1));
      font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial;
      color:var(--text);
      padding:22px;
    }

    .wrap{
      width:min(980px, 96vw);
      display:grid;
      grid-template-columns: 1.15fr .85fr;
      gap:16px;
      align-items:stretch;
    }

    @media (max-width: 880px){
      .wrap{ grid-template-columns: 1fr; }
    }

    .panel{
      border:1px solid var(--line);
      background: linear-gradient(180deg, var(--card), var(--card2));
      border-radius:18px;
      box-shadow: 0 22px 90px var(--shadow);
      overflow:hidden;
      position:relative;
    }

    .top{
      padding:22px 22px 14px;
      display:flex;
      gap:14px;
      align-items:center;
      background: linear-gradient(90deg, rgba(255,0,0,.18), rgba(255,255,255,0));
      border-bottom:1px solid rgba(255,255,255,.06);
    }

    .brand{
      width:46px;height:46px;border-radius:14px;
      display:grid;place-items:center;
      background: rgba(255,0,0,.14);
      border:1px solid rgba(255,0,0,.28);
      box-shadow: 0 0 0 7px rgba(255,0,0,.06);
      overflow:hidden;
      flex:0 0 auto;
    }

    .brand svg{ width:30px;height:30px; display:block; }

    .hgroup h1{
      margin:0;
      font-size:18px;
      letter-spacing:.25px;
      text-shadow: 0 0 18px rgba(255,0,0,.25);
    }
    .hgroup .sub{
      margin-top:4px;
      font-size:13px;
      color:var(--muted);
    }

    .tabs{
      display:flex;
      gap:10px;
      padding:14px 22px 0;
    }
    .tab{
      display:inline-flex;
      gap:8px;
      align-items:center;
      padding:10px 12px;
      border-radius:999px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      color: rgba(234,234,242,.86);
      font-size:12px;
      text-decoration:none;
    }
    .tab.active{
      background: rgba(0,160,255,.10);
      border-color: rgba(0,160,255,.30);
      box-shadow: 0 0 0 6px rgba(0,160,255,.06);
    }

    .mid{
      padding:18px 22px 8px;
    }

    .alert{
      border-radius:14px;
      border:1px solid rgba(255,255,255,.10);
      padding:12px 12px;
      margin:0 0 14px;
      background: rgba(0,0,0,.22);
      font-size:13px;
      line-height:1.45;
    }
    .alert.danger{
      border-color: rgba(255,77,77,.35);
      background: rgba(255,77,77,.10);
    }

    .grid{
      display:grid;
      grid-template-columns: 1fr;
      gap:12px;
    }

    label{
      display:block;
      font-size:12px;
      color: rgba(234,234,242,.78);
      margin:0 0 6px;
    }

    .inp{
      width:100%;
      padding:12px 12px;
      border-radius:14px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(0,0,0,.28);
      color: var(--text);
      outline:none;
      font-size:14px;
      transition: border-color .15s ease, box-shadow .15s ease, transform .08s ease;
    }
    .inp:focus{
      border-color: rgba(0,160,255,.45);
      box-shadow: 0 0 0 6px var(--focus);
    }

    .row{
      display:flex;
      justify-content:space-between;
      align-items:center;
      gap:12px;
      margin-top:6px;
      flex-wrap:wrap;
    }

    .check{
      display:flex;
      align-items:center;
      gap:10px;
      font-size:12px;
      color: rgba(234,234,242,.80);
      user-select:none;
    }
    .check input{
      width:16px;height:16px;
      accent-color: #00a0ff;
    }

    .btn{
      width:100%;
      border:0;
      border-radius:14px;
      padding:12px 14px;
      font-weight:700;
      cursor:pointer;
      color:#fff;
      background: linear-gradient(90deg, rgba(255,0,51,.65), rgba(0,160,255,.65));
      box-shadow: 0 18px 60px rgba(0,0,0,.35);
      transition: transform .08s ease, filter .15s ease;
    }
    .btn:hover{ filter: brightness(1.05); }
    .btn:active{ transform: translateY(1px); }

    .link{
      font-size:12px;
      color: rgba(234,234,242,.86);
      text-decoration:none;
      border-bottom:1px dashed rgba(234,234,242,.28);
    }
    .link:hover{ border-bottom-color: rgba(0,160,255,.60); }

    .bot{
      display:flex;
      justify-content:space-between;
      align-items:center;
      padding:14px 22px;
      border-top:1px solid rgba(255,255,255,.06);
      background: rgba(0,0,0,.18);
      color: rgba(234,234,242,.70);
      font-size:12px;
      gap:10px;
      flex-wrap:wrap;
    }
    .wm{ font-weight:800; color:#fff; }

    /* Right side info card */
    .side{
      border:1px solid rgba(255,255,255,.08);
      background: linear-gradient(180deg, rgba(255,255,255,.05), rgba(255,255,255,.02));
      border-radius:18px;
      box-shadow: 0 22px 90px rgba(0,0,0,.45);
      overflow:hidden;
      position:relative;
    }
    .side .pad{ padding:22px; }
    .kicker{
      font-size:12px;
      letter-spacing:.18em;
      text-transform:uppercase;
      color: rgba(234,234,242,.68);
    }
    .big{
      margin:10px 0 0;
      font-size:20px;
      line-height:1.25;
      text-shadow: 0 0 18px rgba(255,0,0,.18);
    }
    .muted{ color: rgba(234,234,242,.72); font-size:13px; line-height:1.55; margin-top:10px; }
    .codebox{
      margin-top:14px;
      padding:14px 14px;
      border-radius:14px;
      border:1px solid rgba(255,255,255,.08);
      background: rgba(0,0,0,.25);
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace;
      font-size:12px;
      color:#f3f3ff;
      line-height:1.6;
      overflow:auto;
    }
    .pillbar{ display:flex; flex-wrap:wrap; gap:8px; margin-top:12px; }
    .pill{
      font-size:12px; padding:8px 10px; border-radius:999px;
      border:1px solid rgba(255,255,255,.10);
      background: rgba(255,255,255,.04);
      color: rgba(234,234,242,.86);
    }
  </style>
</head>

<body>
  <div class="wrap">

    <div class="panel">
      <div class="top">
        <div class="brand" aria-label="D Logo">
          <!-- Logo D (SVG) -->
          <svg viewBox="0 0 64 64" role="img" aria-hidden="true">
            <defs>
              <linearGradient id="g" x1="0" x2="1" y1="0" y2="1">
                <stop offset="0" stop-color="#ff0033"/>
                <stop offset="1" stop-color="#00a0ff"/>
              </linearGradient>
            </defs>
            <path fill="url(#g)" d="M22 12h16c12 0 22 10 22 20S50 52 38 52H22a6 6 0 0 1-6-6V18a6 6 0 0 1 6-6Zm6 10v20h10c6 0 12-4 12-10s-6-10-12-10H28Z"/>
          </svg>
        </div>

        <div class="hgroup">
          <h1>Welcome back</h1>
          <div class="sub">Sign in to continue • Secure UI Layer</div>
        </div>
      </div>

      <div class="tabs">
        <a class="tab active" href="{{ url('/auth/login') }}">🔐 Login</a>
        <a class="tab" href="{{ url('/') }}">🏠 Home</a>
        @if (\Illuminate\Support\Facades\Route::has('auth.password'))
          <a class="tab" href="{{ route('auth.password') }}">🧩 Reset</a>
        @endif
      </div>

      <div class="mid">
        @if ($errors->any())
          <div class="alert danger">
            <b>Login gagal:</b>
            <ul style="margin:8px 0 0; padding-left:18px;">
              @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
              @endforeach
            </ul>
          </div>
        @endif

        <form method="POST" action="{{ url('/auth/login') }}">
          @csrf

          <div class="grid">
            <div>
              <label for="user">Username / Email</label>
              <input id="user" class="inp" type="text" name="user" value="{{ old('user') }}" autocomplete="username" required autofocus>
            </div>

            <div>
              <label for="password">Password</label>
              <input id="password" class="inp" type="password" name="password" autocomplete="current-password" required>
            </div>

            <div class="row">
              <label class="check">
                <input type="checkbox" name="remember" value="1" {{ old('remember') ? 'checked' : '' }}>
                Remember me
              </label>

              @if (\Illuminate\Support\Facades\Route::has('auth.password'))
                <a class="link" href="{{ route('auth.password') }}">Forgot password?</a>
              @endif
            </div>

            <button class="btn" type="submit">Sign in</button>
          </div>
        </form>
      </div>

      <div class="bot">
        <div>Security Layer: <b>Dezz Shield</b> • Status: <span style="color: var(--ok); font-weight:800;">ENABLED</span></div>
        <div class="wm">Protect Panel By Dezz</div>
      </div>
    </div>

    <div class="side">
      <div class="pad">
        <div class="kicker">SYSTEM NOTICE</div>
        <div class="big">Aesthetic Login • Clean • Fast</div>
        <div class="muted">
          Halaman login ini custom. Logo Pterodactyl disembunyikan dan diganti monogram <b>D</b>.
          Responsive (mobile friendly) dan tetap pakai route <code>/auth/login</code>.
        </div>

        <div class="codebox">
HTTP/1.1 200 OK<br/>
Endpoint: /auth/login<br/>
Theme: Dark Glass + Gradient<br/>
Logo: D Monogram
        </div>

        <div class="pillbar">
          <div class="pill">No extra commands</div>
          <div class="pill">Auto recompile view</div>
          <div class="pill">Mobile ready</div>
        </div>
      </div>

      <div class="bot">
        <div>UI Build: <b>Kece Mode</b> • Version: <span style="opacity:.9;">1</span></div>
        <div class="wm">D</div>
      </div>
    </div>

  </div>
</body>
</html>
EOF

chmod 644 "$LOGIN_VIEW"

hr
ok "DONE! Login page sudah diganti."
info "URL: ${BOLD}/auth/login${NC}"
info "Backup: ${BOLD}${BACKUP}${NC}"
hr
echo -e "${WHT}${BOLD}WM:${NC} ${CYN}Protect Panel By Dezz${NC}"
hr
