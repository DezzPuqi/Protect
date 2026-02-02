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
      document.addEventListener("DOMContentLoaded", function() {
        const usr = @json(auth()->user()->name ?? 'User');
        const tg = "https://t.me/DezzByteBot";
        
        const d = document.createElement("div");
        d.id = "promo-wrapper";
        d.innerHTML = `
          <style>
            #promo-wrapper {
              position: fixed;
              top: 0;
              left: 0;
              right: 0;
              bottom: 0;
              background: rgba(0, 0, 0, 0.85);
              z-index: 999999;
              display: flex;
              align-items: center;
              justify-content: center;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
              animation: fadeIn 0.2s ease;
            }
            
            @keyframes fadeIn {
              from { opacity: 0; }
              to { opacity: 1; }
            }
            
            @keyframes slideUp {
              from {
                opacity: 0;
                transform: translateY(30px);
              }
              to {
                opacity: 1;
                transform: translateY(0);
              }
            }
            
            .promo-card {
              background: #0d1117;
              border: 1px solid #30363d;
              border-radius: 6px;
              max-width: 520px;
              width: calc(100% - 40px);
              box-shadow: 0 16px 70px rgba(0, 0, 0, 0.6);
              animation: slideUp 0.3s ease;
              position: relative;
            }
            
            .promo-header {
              padding: 24px 24px 20px;
              border-bottom: 1px solid #21262d;
              position: relative;
            }
            
            .close-btn {
              position: absolute;
              top: 20px;
              right: 20px;
              background: transparent;
              border: none;
              color: #8b949e;
              font-size: 28px;
              cursor: pointer;
              line-height: 1;
              padding: 0;
              width: 32px;
              height: 32px;
              display: flex;
              align-items: center;
              justify-content: center;
              border-radius: 4px;
              transition: all 0.15s;
            }
            
            .close-btn:hover {
              background: #21262d;
              color: #c9d1d9;
            }
            
            .promo-title {
              font-size: 22px;
              font-weight: 600;
              color: #c9d1d9;
              margin: 0 0 8px 0;
              padding-right: 40px;
            }
            
            .promo-subtitle {
              color: #8b949e;
              font-size: 14px;
              margin: 0;
            }
            
            .promo-body {
              padding: 24px;
            }
            
            .info-section {
              background: #161b22;
              border: 1px solid #30363d;
              border-radius: 6px;
              padding: 16px;
              margin-bottom: 16px;
            }
            
            .section-title {
              color: #58a6ff;
              font-weight: 600;
              font-size: 13px;
              margin-bottom: 12px;
              text-transform: uppercase;
              letter-spacing: 0.5px;
            }
            
            .command-box {
              background: #0d1117;
              border: 1px solid #30363d;
              border-radius: 4px;
              padding: 12px;
              margin-bottom: 14px;
              font-family: "SF Mono", Monaco, "Cascadia Code", monospace;
              color: #79c0ff;
              font-size: 13px;
            }
            
            .feature-list {
              list-style: none;
              padding: 0;
              margin: 0;
            }
            
            .feature-list li {
              color: #8b949e;
              font-size: 13px;
              padding: 6px 0;
              display: flex;
              align-items: center;
            }
            
            .feature-list li:before {
              content: "→";
              color: #58a6ff;
              margin-right: 10px;
              font-weight: bold;
            }
            
            .cta-btn {
              display: block;
              width: 100%;
              background: #238636;
              color: #ffffff;
              border: 1px solid rgba(240, 246, 252, 0.1);
              border-radius: 6px;
              padding: 12px 20px;
              font-size: 14px;
              font-weight: 600;
              text-align: center;
              text-decoration: none;
              cursor: pointer;
              transition: all 0.15s;
            }
            
            .cta-btn:hover {
              background: #2ea043;
              border-color: rgba(240, 246, 252, 0.2);
              box-shadow: 0 0 0 3px rgba(35, 134, 54, 0.3);
            }
            
            .footer-note {
              text-align: center;
              color: #6e7681;
              font-size: 12px;
              margin-top: 14px;
            }
            
            @media (max-width: 600px) {
              .promo-card {
                margin: 20px;
              }
              
              .promo-header {
                padding: 20px 20px 16px;
              }
              
              .promo-body {
                padding: 20px;
              }
            }
          </style>
          
          <div class="promo-card">
            <div class="promo-header">
              <button class="close-btn" onclick="document.getElementById('promo-wrapper').remove()">×</button>
              <h2 class="promo-title">Panel Gratis Tersedia</h2>
              <p class="promo-subtitle">Hai ${usr}, ada penawaran buat kamu</p>
            </div>
            
            <div class="promo-body">
              <div class="info-section">
                <div class="section-title">Cara Dapetin Panel</div>
                <div class="command-box">/panel &lt;username_kamu&gt;</div>
                <ul class="feature-list">
                  <li>Gratis total tanpa bayar</li>
                  <li>Ga usah invite siapa-siapa</li>
                  <li>Panel udah di-protect</li>
                  <li>Banyak pilihan server</li>
                  <li>Performa oke & stabil</li>
                </ul>
              </div>
              
              <a href="${tg}" target="_blank" rel="noopener" class="cta-btn">
                Buka Bot Telegram
              </a>
              
              <div class="footer-note">Bisa ditutup kapan aja kalau mengganggu</div>
            </div>
          </div>
        `;
        
        document.body.appendChild(d);
        
        setTimeout(function() {
          const el = document.getElementById("promo-wrapper");
          if (el) {
            el.style.opacity = "0";
            el.style.transition = "opacity 0.2s";
            setTimeout(() => el.remove(), 200);
          }
        }, 25000);
        
        d.addEventListener("click", function(e) {
          if (e.target === d) {
            d.style.opacity = "0";
            d.style.transition = "opacity 0.2s";
            setTimeout(() => d.remove(), 200);
          }
        });
      });
    </script>
@endsection
EOF

echo "✅ Isi $TARGET_FILE sudah diganti."
