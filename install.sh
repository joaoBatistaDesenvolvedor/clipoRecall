#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"

# ── 1. Backend Docker ─────────────────────────────────────────────────────────
echo "🐳  Iniciando backend Docker…"
cd "$ROOT"
docker compose up -d --build
echo "✅  Backend rodando em http://localhost:8765"

# ── 2. Compilar app Swift ─────────────────────────────────────────────────────
echo ""
echo "🔨  Compilando ClipRecall…"
cd "$ROOT"
swift build -c release 2>&1
echo "✅  Compilado."

# ── 3. Instalar em ~/Applications ────────────────────────────────────────────
echo ""
echo "📦  Instalando em ~/Applications/ClipRecall.app…"
APP_BUNDLE="$HOME/Applications/ClipRecall.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$ROOT/.build/release/ClipRecall" "$APP_BUNDLE/Contents/MacOS/ClipRecall"

cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClipRecall</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.cliprecall</string>
    <key>CFBundleName</key>
    <string>ClipRecall</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
PLIST

echo "✅  Instalado."

# ── 4. Lançar ─────────────────────────────────────────────────────────────────
echo ""
kill $(pgrep -x ClipRecall) 2>/dev/null || true
open "$APP_BUNDLE"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ClipRecall instalado e rodando!         ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Atalho global: ⌘ + ⇧ + V              ║"
echo "║  Ou clique no ícone 📋 na barra         ║"
echo "║  Backend: http://localhost:8765          ║"
echo "╚══════════════════════════════════════════╝"
