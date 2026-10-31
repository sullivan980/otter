#!/bin/bash
# 构建 .app → 组装 DMG（拖拽安装 + 卷标）→ 校验
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"

APP="$ROOT/build/Otter.app"
VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
OUT="$ROOT/build/Otter-$VER.dmg"
STAGE="$(mktemp -d)/Otter"

mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Otter.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/Resources/icon.icns" "$STAGE/.VolumeIcon.icns"
/usr/bin/SetFile -a C "$STAGE" 2>/dev/null || true

rm -f "$OUT"
hdiutil create -volname Otter -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null
hdiutil verify "$OUT" | tail -1
rm -rf "$(dirname "$STAGE")"
cp "$OUT" "$ROOT/Otter.dmg"
echo "dmg: $OUT"
