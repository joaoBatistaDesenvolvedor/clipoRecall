#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"

# ── 1. Backend Docker ─────────────────────────────────────────────────────────
echo "🐳  Instalando backend em ~/.cliprecall…"
BACKEND_DIR="$HOME/.cliprecall"
mkdir -p "$BACKEND_DIR"
cp -r "$ROOT/backend" "$BACKEND_DIR/backend"
cp "$ROOT/docker-compose.yml" "$BACKEND_DIR/docker-compose.yml"

# Garante que o Docker Desktop está rodando
DOCKER_SOCK="$HOME/.docker/run/docker.sock"
if ! docker info &>/dev/null; then
    echo "  Iniciando Docker Desktop…"
    open -a Docker
    for i in $(seq 1 40); do
        sleep 2
        docker info &>/dev/null && break
        printf "."
    done
    echo ""
fi

cd "$BACKEND_DIR"
docker compose up -d --build
echo "✅  Backend rodando em http://localhost:8765"

# ── 2. Compilar app Swift ─────────────────────────────────────────────────────
echo ""
echo "🔨  Compilando ClipRecall…"
cd "$ROOT"
swift build -c release 2>&1
echo "✅  Compilado."

# ── 3. Gerar ícone ────────────────────────────────────────────────────────────
echo ""
echo "🎨  Gerando ícone…"
ICONSET="$ROOT/.build/AppIcon.iconset"
ICNS="$ROOT/.build/AppIcon.icns"
swift "$ROOT/scripts/make_icon.swift" "$ICONSET" 2>&1
iconutil -c icns "$ICONSET" -o "$ICNS"
echo "✅  Ícone gerado."

# ── 4. Instalar em ~/Applications ────────────────────────────────────────────
echo ""
echo "📦  Instalando em ~/Applications/ClipRecall.app…"
APP_BUNDLE="$HOME/Applications/ClipRecall.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$ROOT/.build/release/ClipRecall" "$APP_BUNDLE/Contents/MacOS/ClipRecall"
cp "$ICNS" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClipRecall</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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

# ── 5. Lançar ─────────────────────────────────────────────────────────────────
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
