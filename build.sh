#!/bin/bash
# Compila e monta build/Fala.app (assinatura ad-hoc, sem Xcode).
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=build/Fala.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Fala "$APP/Contents/MacOS/Fala"
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/* "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Pronto: $APP"

# ./build.sh --install  →  instala/atualiza em /Applications e abre
if [ "${1:-}" = "--install" ]; then
    pkill -f 'Fala.app/Contents/MacOS/Fala' || true
    rm -rf /Applications/Fala.app
    cp -R "$APP" /Applications/Fala.app
    open /Applications/Fala.app
    echo "Instalado: /Applications/Fala.app"
fi
