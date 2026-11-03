#!/bin/bash
# Otter 原生版构建：编译 Swift → 组装 .app（原子替换）→ 拷资源 → ad-hoc 签名
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Otter.app"
STAGE="$ROOT/build/.stage/Otter.app"
# 构建锁：串行化，避免并发删产物；超过 15 分钟的锁视为残留
mkdir -p "$ROOT/build"
LOCK="$ROOT/build/.buildlock"
if [ -d "$LOCK" ] && [ "$(find "$LOCK" -maxdepth 0 -mmin +15 2>/dev/null | wc -l | tr -d " ")" = "1" ]; then
  rm -rf "$LOCK"
fi
while ! mkdir "$LOCK" 2>/dev/null; do sleep 1; done
trap 'rmdir "$LOCK" 2>/dev/null || true; rm -rf "$ROOT/build/.stage" 2>/dev/null || true' EXIT

# SwiftUI 的 @State 等宏需要 SwiftUIMacros 插件；当前 CommandLineTools 27.x 的 SDK 缺该插件，
# 用 26.5 SDK 可正常编译。可用 OTTER_SDK 覆盖。
SDK="${OTTER_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
if [ ! -d "$SDK" ]; then SDK="$(xcrun --show-sdk-path)"; fi
CACHE="/tmp/otter-swift-mc"

rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"

SRC=$(find "$ROOT/Sources" -name "*.swift" | sort)
# shellcheck disable=SC2086
TARGET="${OTTER_TARGET:-$(uname -m)-apple-macos13.0}"
swiftc -O -sdk "$SDK" -target "$TARGET" -module-cache-path "$CACHE" \
  -framework AppKit -framework SwiftUI -framework ServiceManagement -framework UserNotifications \
  "$SRC" -o "$STAGE/Contents/MacOS/Otter"

cp "$ROOT/Resources/Info.plist" "$STAGE/Contents/Info.plist"
cp "$ROOT/Resources/icon.icns" "$STAGE/Contents/Resources/icon.icns"
if [ -d "$ROOT/Resources/plugins" ]; then
  rsync -a "$ROOT/Resources/plugins/" "$STAGE/Contents/Resources/plugins/"
fi
chmod +x "$STAGE/Contents/MacOS/Otter"
codesign --force --deep --sign - "$STAGE" >/dev/null 2>&1 || true

# 原子替换：编译失败时旧产物仍然可用
rm -rf "$APP"
mv "$STAGE" "$APP"
rm -rf "$ROOT/build/.stage"
echo "built: $APP"