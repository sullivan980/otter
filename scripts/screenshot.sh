#!/bin/bash
# =====================================================================
# Otter 原生版 · 批量截图（人工验收用）
# 输出目录默认 /tmp/otter2-shots/：
#   hud.png、main-clean.png、main-uninstall.png、main-disk.png、main-settings.png、menu-bar.png
# 用法：./scripts/screenshot.sh [--out DIR] [--only hud|clean|uninstall|disk|settings|all]
#                               [--keep] [--full]
# 红线：只启动 / 截图 / 关闭应用，不执行任何清理、优化、删除。
# 说明：为兼容 macOS bash 3.2，本脚本不使用花括号变量写法。
# =====================================================================
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/lib.sh"

OUT="/tmp/otter2-shots"
ONLY="all"
KEEP=0
FULL=0
usage() {
  echo "用法：$0 [--out DIR] [--only hud|clean|uninstall|disk|settings|all] [--keep] [--full]"
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      shift
      if [ "$#" -gt 0 ]; then OUT="$1"; fi
      shift
      ;;
    --only)
      shift
      if [ "$#" -gt 0 ]; then ONLY="$1"; fi
      shift
      ;;
    --keep) KEEP=1; shift ;;
    --full) FULL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1"; usage; exit 3 ;;
  esac
done

CAPTURED=0
FAILED=0
mkdir -p "$OUT" 2>/dev/null || true

shot_window() {
  local wid file label
  wid="$1"
  file="$2"
  label="$3"
  if screencapture -l "$wid" -x -o "$file" 2>/dev/null; then
    CAPTURED=$((CAPTURED + 1))
    echo "  [OK] $label → $file"
  else
    FAILED=$((FAILED + 1))
    echo "  [FAIL] $label 截图失败（window id=$wid""）"
  fi
}

capture_menubar() {
  local full pw
  full="$T5_TMP/screen-full.png"
  if ! screencapture -x "$full" 2>/dev/null; then
    echo "  [FAIL] 菜单栏：全屏截图失败（检查系统「屏幕录制」权限）"
    FAILED=$((FAILED + 1))
    return
  fi
  pw="$(sips -g pixelWidth "$full" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
  if [ -z "$pw" ]; then
    echo "  [FAIL] 菜单栏：无法读取截图像素宽度"
    FAILED=$((FAILED + 1))
    rm -f "$full"
    return
  fi
  if sips -c 80 "$pw" --cropOffset 0 0 "$full" --out "$OUT/menu-bar.png" >/dev/null 2>&1; then
    CAPTURED=$((CAPTURED + 1))
    echo "  [OK] 菜单栏（顶部 80px）→ $OUT/menu-bar.png"
  else
    FAILED=$((FAILED + 1))
    echo "  [FAIL] 菜单栏裁剪失败（sips）"
  fi
  if [ "$FULL" -eq 1 ]; then
    cp "$full" "$OUT/fullscreen.png" 2>/dev/null || true
    echo "  [OK] 全屏 → $OUT/fullscreen.png"
  fi
  rm -f "$full"
}

capture_hud() {
  local log pid wid
  t5_kill_app
  log="$T5_TMP/shot-hud.log"
  if ! t5_open_app "-OTTER_NO_ONBOARD=1" "-OTTER_SHOW_HUD=1"; then
    echo "  [FAIL] HUD：LaunchServices 启动失败（open $T5_APP""）"
    FAILED=$((FAILED + 1))
    return
  fi
  pid="$T5_APP_PID"
  sleep 1.2
  wid="$(t5_wait_window "$pid" "400x520" "" 10)"
  if [ -z "$wid" ]; then
    echo "  [FAIL] HUD：未找到 400x520 窗口（日志：$log""）"
    FAILED=$((FAILED + 1))
    return
  fi
  shot_window "$wid" "$OUT/hud.png" "HUD 400x520"
  capture_menubar
}

capture_main() {
  local sec log pid wid
  sec="$1"
  t5_kill_app
  log="$T5_TMP/shot-main-$sec.log"
  if ! t5_open_app "-OTTER_NO_ONBOARD=1" "-OTTER_SHOW_MAIN=1" "-OTTER_MAIN_SECTION=$sec" "-OTTER_AUTO_SCAN=$sec"; then
    echo "  [FAIL] 主界面 $sec""：LaunchServices 启动失败（open $T5_APP""）"
    FAILED=$((FAILED + 1))
    return
  fi
  pid="$T5_APP_PID"
  if [ "$sec" = "clean" ]; then
    sleep 22
  elif [ "$sec" = "uninstall" ]; then
    sleep 4
  else
    sleep 1.5
  fi
  wid="$(t5_wait_window "$pid" "" "Otter" 10)"
  if [ -z "$wid" ]; then
    wid="$(t5_wait_window_not_size "$pid" "400x520" 3)"
  fi
  if [ -z "$wid" ]; then
    echo "  [FAIL] 主界面 $sec""：未找到主窗口（日志：$log""）"
    FAILED=$((FAILED + 1))
    return
  fi
  shot_window "$wid" "$OUT/main-$sec.png" "主界面·$sec"
}

echo "== Otter 批量截图（输出目录：$OUT""） =="
if [ ! -x "$T5_BIN" ]; then
  echo "[FAIL] 构建产物不存在：$T5_BIN""（先运行 scripts/build.sh）"
  exit 3
fi

case "$ONLY" in
  all)
    capture_hud
    capture_main clean
    capture_main uninstall
    capture_main disk
    capture_main settings
    ;;
  hud) capture_hud ;;
  clean|uninstall|disk|settings) capture_main "$ONLY" ;;
  *)
    echo "未知 --only 值：$ONLY"
    usage
    exit 3
    ;;
esac

if [ "$KEEP" -eq 0 ]; then
  t5_kill_app
else
  echo "  --keep：保留最后启动的应用进程"
fi

echo "----------------------------------------"
printf '截图完成：成功 %d / 失败 %d\n' "$CAPTURED" "$FAILED"
echo "输出目录：$OUT"
ls -1 "$OUT"/*.png 2>/dev/null | sed 's/^/  /'
if [ "$FAILED" -gt 0 ]; then exit 1; fi
exit 0
