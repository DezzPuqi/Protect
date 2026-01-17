#!/bin/bash

TARGET_FILE="/var/www/pterodactyl/resources/views/templates/base/core.blade.php"
BACKUP_FILE="${TARGET_FILE}.bak_$(date -u +"%Y-%m-%d-%H-%M-%S")"

echo "🚀 Mengganti isi $TARGET_FILE..."

# Backup dulu file lama
if [ -f "$TARGET_FILE" ]; then
  cp "$TARGET_FILE" "$BACKUP_FILE"
  echo "📦 Backup file lama dibuat di $BACKUP_FILE"
fi

cat > "$TARGET_FILE" << 'EOF'
@extends('templates/wrapper', [
    'css' => ['body' => 'bg-neutral-800'],
])

@section('container')
    <div id="modal-portal"></div>
    <div id="app"></div>

    <script>
      document.addEventListener("DOMContentLoaded", () => {
        const username = @json(auth()->user()->name ?? 'User');
        const tgLink = "https://t.me/SiDezzBot";

        // Container (card iklan)
        const card = document.createElement("div");
        card.setAttribute("role", "dialog");
        card.setAttribute("aria-live", "polite");

        card.innerHTML = `
          <div style="display:flex; align-items:center; justify-content:space-between; gap:10px; margin-bottom:10px;">
            <div style="display:flex; align-items:center; gap:10px;">
              <div style="
                width:34px; height:34px; border-radius:10px;
                background: linear-gradient(135deg, #22c55e, #3b82f6);
                box-shadow: 0 8px 18px rgba(0,0,0,0.35);
                display:flex; align-items:center; justify-content:center;
                font-weight:900; color:#0b1220; font-family: monospace;
              ">⚡</div>

              <div style="line-height:1.1;">
                <div style="font-weight:800; font-size:14px;">Mau Panel Free?</div>
                <div style="opacity:.85; font-size:12px;">Hai ${username} 👋</div>
              </div>
            </div>

            <button id="ad-close" title="Tutup" style="
              all:unset; cursor:pointer;
              width:28px; height:28px; border-radius:10px;
              display:flex; align-items:center; justify-content:center;
              background: rgba(255,255,255,0.08);
              box-shadow: inset 0 0 0 1px rgba(255,255,255,0.08);
              color:#fff; font-size:16px; line-height:1;
            ">✕</button>
          </div>

          <div style="
            font-size:12px; opacity:.95; margin-bottom:10px;
            background: rgba(0,0,0,0.25);
            border-radius: 12px;
            padding: 10px;
            box-shadow: inset 0 0 0 1px rgba(255,255,255,0.06);
          ">
            <div style="font-weight:700; margin-bottom:6px;">
              Sini di bot gua lu bisa create panel free
            </div>

            <div style="display:flex; gap:8px; flex-wrap:wrap; margin:10px 0;">
              ${Array.from({length: 5}).map(() => `
                <a href="${tgLink}" target="_blank" rel="noopener" style="
                  text-decoration:none; color:#0b1220; font-weight:900;
                  background: linear-gradient(135deg, #facc15, #fb7185);
                  padding: 8px 10px; border-radius: 12px;
                  box-shadow: 0 10px 18px rgba(0,0,0,0.35);
                  font-size:12px; font-family: monospace;
                ">CLICK HERE</a>
              `).join("")}
            </div>

            <div style="margin-top:8px; font-weight:800;">Gampang caranya cukup:</div>
            <div style="font-family: monospace; margin:6px 0 10px; padding:8px 10px; border-radius:12px;
                        background: rgba(255,255,255,0.06);
                        box-shadow: inset 0 0 0 1px rgba(255,255,255,0.06);">
              /panel &lt;username yg kamu mau&gt;<br/>
              Lalu pilih ukuran RAM yang kamu mau
            </div>

            <ul style="margin:0; padding-left:16px; line-height:1.55;">
              <li><b>100% Gratis</b> — Tidak bayar sama sekali</li>
              <li>Tidak perlu invite user lain</li>
              <li>Panel berprotect</li>
              <li>Server lebih dari 1</li>
              <li>Server banyakkkk</li>
              <li><b>80% Panel lancar</b></li>
            </ul>
          </div>

          <a href="${tgLink}" target="_blank" rel="noopener" style="
            display:block; text-decoration:none; text-align:center;
            padding: 10px 12px; border-radius: 14px;
            background: linear-gradient(135deg, #22c55e, #3b82f6);
            color:#0b1220; font-weight:1000; letter-spacing: .4px;
            box-shadow: 0 14px 28px rgba(0,0,0,0.45);
            font-family: monospace;
          ">
            OPEN BOT: t.me/SiDezzBot
          </a>

          <div style="margin-top:10px; font-size:11px; opacity:.7; text-align:center;">
            Iklan akan hilang otomatis • bisa ditutup kapan aja
          </div>
        `;

        Object.assign(card.style, {
          position: "fixed",
          bottom: "20px",
          right: "20px",
          width: "min(380px, calc(100vw - 40px))",
          background: "rgba(15, 23, 42, 0.92)",
          color: "#fff",
          padding: "14px",
          borderRadius: "18px",
          fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, Arial",
          boxShadow: "0 20px 60px rgba(0,0,0,0.55)",
          zIndex: "9999",
          backdropFilter: "blur(10px)",
          border: "1px solid rgba(255,255,255,0.08)",
          opacity: "0",
          transform: "translateY(10px)",
          transition: "opacity .35s ease, transform .35s ease"
        });

        document.body.appendChild(card);

        // Animasi masuk
        requestAnimationFrame(() => {
          card.style.opacity = "1";
          card.style.transform = "translateY(0)";
        });

        const close = () => {
          card.style.opacity = "0";
          card.style.transform = "translateY(10px)";
          setTimeout(() => card.remove(), 400);
        };

        // Tombol close
        const closeBtn = card.querySelector("#ad-close");
        if (closeBtn) closeBtn.addEventListener("click", close);

        // Auto-hide (misal 20 detik)
        const autoHideMs = 20000;
        const t = setTimeout(close, autoHideMs);

        // Kalau user hover, tunda auto-hide biar kebaca
        card.addEventListener("mouseenter", () => clearTimeout(t));
      });
    </script>
@endsection
EOF

echo "✅ Isi $TARGET_FILE sudah diganti dengan konten iklan baru."
