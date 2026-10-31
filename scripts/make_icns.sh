#!/bin/bash
# 从一张 1024x1024 PNG 生成 Otter.icns 并替换 Resources/icon.icns
# 用法: ./scripts/make_icns.sh path/to/otter-1024.png
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$1"
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
  echo "用法: make_icns.sh <1024x1024.png>"; exit 1
fi

W=$(sips -g pixelWidth "$SRC" | awk '/pixelWidth/{print $2}')
H=$(sips -g pixelHeight "$SRC" | awk '/pixelHeight/{print $2}')
if [ "$W" != "1024" ] || [ "$H" != "1024" ]; then
  echo "需要 1024x1024，当前 $W x $H"; exit 1
fi

SET="$ROOT/build/Otter.iconset"
rm -rf "$SET"
mkdir -p "$SET"

sips -z 16 16 "$SRC" --out "$SET/icon_16x16.png" >/dev/null
sips -z 32 32 "$SRC" --out "$SET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$SRC" --out "$SET/icon_32x32.png" >/dev/null
sips -z 64 64 "$SRC" --out "$SET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$SRC" --out "$SET/icon_128x128.png" >/dev/null
sips -z 256 256 "$SRC" --out "$SET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SRC" --out "$SET/icon_256x256.png" >/dev/null
sips -z 512 512 "$SRC" --out "$SET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SRC" --out "$SET/icon_512x512.png" >/dev/null
cp "$SRC" "$SET/icon_512x512@2x.png"

iconutil -c icns "$SET" -o "$ROOT/Resources/icon.icns"
echo "已生成 $ROOT/Resources/icon.icns"
echo "下一步: ./scripts/build.sh（需要分发时再打 DMG）"
