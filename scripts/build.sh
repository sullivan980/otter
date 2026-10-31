#!/bin/bash
# Otter 原生版构建：编译 Swift → 组装 .app → 拷资源 → ad-hoc 签名
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Otter.app"
# 构建锁：团队成员可能并发构建，串行化避免互相删产物
LOCK="$ROOT/build/.buildlock"
while ! mkdir "$LOCK" 2>/dev/null; do sleep 1; done
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
SDK="$(xcrun --show-sdk-path)"
CACHE="/tmp/otter-swift-mc"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SRC=$(find "$ROOT/Sources" -name '*.swift' | sort)
# shellcheck disable=SC2086
swiftc -O -sdk "$SDK" -target arm64-apple-macos13.0 -module-cache-path "$CACHE" \
  -framework AppKit -framework SwiftUI -framework ServiceManagement -framework UserNotifications \
  $SRC -o "$APP/Contents/MacOS/Otter"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/icon.icns" "$APP/Contents/Resources/icon.icns"
rsync -a "$ROOT/Resources/mole/" "$APP/Contents/Resources/mole/"
chmod +x "$APP/Contents/MacOS/Otter" "$APP/Contents/Resources/mole/mole"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "built: $APP"