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

        const overlay = document.createElement("div");
        overlay.id = "dezz-ad-overlay";
        Object.assign(overlay.style, {
          position: "fixed",
          inset: "0",
          background: "rgba(0,0,0,0.55)",
          zIndex: "99999",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          padding: "18px",
          backdropFilter: "blur(6px)",
          opacity: "0",
          transition: "opacity .25s ease"
        });

        const card = document.createElement("div");
        Object.assign(card.style, {
          width: "min(520px, calc(100vw - 36px))",
          borderRadius: "22px",
          padding: "18px",
          background: "rgba(17, 24, 39, 0.92)",
          color: "#fff",
          boxShadow: "0 30px 90px rgba(0,0,0,0.65)",
          border: "1px solid rgba(255,255,255,0.10)",
          transform: "translateY(8px) scale(0.98)",
          transition: "transform .25s ease",
          fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, Arial"
        });

        const header = document.createElement("div");
        Object.assign(header.style, {
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          gap: "12px",
          marginBottom: "12px"
        });

        const logo = document.createElement("div");
        logo.innerText = "D";
        Object.assign(logo.style, {
          width: "42px",
          height: "42px",
          borderRadius: "14px",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontWeight: "900",
          fontSize: "18px",
          letterSpacing: "0.5px",
          color: "#0b1220",
          background: "linear-gradient(135deg, #22c55e, #3b82f6)",
          boxShadow: "0 14px 26px rgba(0,0,0,0.45)",
          userSelect: "none",
          fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace"
        });

        const closeBtn = document.createElement("button");
        closeBtn.type = "button";
        closeBtn.innerText = "✕";
        Object.assign(closeBtn.style, {
          all: "unset",
          cursor: "pointer",
          width: "34px",
          height: "34px",
          borderRadius: "12px",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: "rgba(255,255,255,0.08)",
          boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.10)",
          color: "#fff",
          fontSize: "16px",
          lineHeight: "1"
        });

        header.appendChild(logo);
        header.appendChild(closeBtn);

        const title = document.createElement("div");
        title.innerHTML = `
          <div style="font-size:18px; font-weight:900; margin-bottom:6px;">
            Mau panel free?
          </div>
          <div style="opacity:.86; font-size:13px; line-height:1.45;">
            Hai ${username}, kalo mau bikin panel gratis tinggal lewat bot aja kok.
          </div>
        `;

        const box = document.createElement("div");
        Object.assign(box.style, {
          marginTop: "12px",
          padding: "12px",
          borderRadius: "16px",
          background: "rgba(255,255,255,0.06)",
          boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.08)"
        });

        box.innerHTML = `
          <div style="font-weight:800; margin-bottom:8px;">Caranya gampang:</div>
          <div style="
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;
            padding: 10px 12px;
            border-radius: 14px;
            background: rgba(0,0,0,0.25);
            box-shadow: inset 0 0 0 1px rgba(255,255,255,0.06);
            line-height: 1.5;
            font-size: 13px;
          ">
            /panel &lt;username lo&gt;<br/>
            terus pilih ukuran RAM yg lo mau
          </div>

          <div style="margin-top:10px; display:grid; gap:6px; font-size:13px; opacity:.92;">
            <div>• gratis total, ga bayar sepeserpun</div>
            <div>• ga perlu invite siapapun</div>
            <div>• panel udah di protect</div>
            <div>• bisa pilih server lebih dari 1</div>
            <div>• pilihan server banyak banget</div>
            <div>• hampir semua lancar jaya</div>
          </div>
        `;

        const cta = document.createElement("a");
        cta.href = tgLink;
        cta.target = "_blank";
        cta.rel = "noopener";
        cta.innerText = "BUKA BOT (t.me/SiDezzBot)";
        Object.assign(cta.style, {
          display: "block",
          marginTop: "14px",
          textDecoration: "none",
          textAlign: "center",
          padding: "12px 14px",
          borderRadius: "16px",
          background: "linear-gradient(135deg, #facc15, #fb7185)",
          color: "#0b1220",
          fontWeight: "1000",
          letterSpacing: ".3px",
          boxShadow: "0 18px 40px rgba(0,0,0,0.55)",
          fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace"
        });

        const note = document.createElement("div");
        note.innerText = "Bisa ditutup kapan aja kalo ganggu.";
        Object.assign(note.style, {
          marginTop: "10px",
          fontSize: "12px",
          opacity: ".65",
          textAlign: "center"
        });

        card.appendChild(header);
        card.appendChild(title);
        card.appendChild(box);
        card.appendChild(cta);
        card.appendChild(note);

        overlay.appendChild(card);
        document.body.appendChild(overlay);

        requestAnimationFrame(() => {
          overlay.style.opacity = "1";
          card.style.transform = "translateY(0) scale(1)";
        });

        const close = () => {
          overlay.style.opacity = "0";
          card.style.transform = "translateY(8px) scale(0.98)";
          setTimeout(() => overlay.remove(), 250);
        };

        closeBtn.addEventListener("click", close);

        overlay.addEventListener("click", (e) => {
          if (e.target === overlay) close();
        });

        setTimeout(() => {
          if (document.getElementById("dezz-ad-overlay")) close();
        }, 25000);
      });
    </script>
@endsection
EOF

echo "✅ Isi $TARGET_FILE sudah diganti."
