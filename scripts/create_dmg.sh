#!/usr/bin/env bash
# Gera ClipRecall.dmg com ícone personalizado
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HOME/Applications/ClipRecall.app"
OUT="$ROOT/ClipRecall.dmg"
TMP_DMG="$ROOT/.build/ClipRecall_rw.dmg"
ICNS="$ROOT/.build/AppIcon.icns"
STAGING="$(mktemp -d)"

echo "📦  Criando DMG…"

# Garante que o ícone existe
if [ ! -f "$ICNS" ]; then
    echo "  Gerando ícone…"
    swift "$ROOT/scripts/make_icon.swift" "$ROOT/.build/AppIcon.iconset"
    iconutil -c icns "$ROOT/.build/AppIcon.iconset" -o "$ICNS"
fi

# Prepara staging
cp -r "$APP" "$STAGING/ClipRecall.app"
ln -s /Applications "$STAGING/Aplicativos"

# Remove DMGs anteriores
rm -f "$OUT" "$TMP_DMG"

# Cria DMG temporário read-write
hdiutil create -volname "ClipRecall" \
    -srcfolder "$STAGING" \
    -ov -format UDRW \
    -fs HFS+ \
    "$TMP_DMG"

# Monta para injetar o ícone do volume
MOUNT_DIR="$(mktemp -d)"
hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

cp "$ICNS" "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -a C "$MOUNT_DIR" 2>/dev/null || \
    osascript -e "tell application \"Finder\" to set icon of disk \"ClipRecall\" to POSIX file \"$ICNS\" as alias" 2>/dev/null || true

hdiutil detach "$MOUNT_DIR" -quiet

# Compacta para DMG final somente-leitura
hdiutil convert "$TMP_DMG" -format UDZO -o "$OUT"
rm -f "$TMP_DMG"
rm -rf "$STAGING" "$MOUNT_DIR"

echo "✅  DMG gerado: $OUT"
open -R "$OUT"
