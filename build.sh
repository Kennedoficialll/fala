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
codesign --force --sign - "$APP"
echo "Pronto: $APP"
