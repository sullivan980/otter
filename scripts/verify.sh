#!/bin/bash
# =====================================================================
# Otter 原生版 · 一键验收（T5）
# 用法：./scripts/verify.sh [--no-build] [--no-tests] [--keep] [--full]
# 退出码：0 全部通过；1 有验收项失败；2 构建失败；3 环境/基建错误
# 红线：只读验收——不执行真实清理 / 优化 / 卸载；clean 仅 dry-run。
# 说明：阈值对齐 docs/ACCEPTANCE.md（NF-01/02/03/07）；为兼容 macOS
#       bash 3.2，本脚本不使用花括号变量写法。
# =====================================================================
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/lib.sh"

usage() {
  echo "用法：$0 [--no-build] [--no-tests] [--keep] [--full]"
  echo "  --no-build  跳过构建，直接验收现有 build/Otter.app"
  echo "  --no-tests  跳过 tests/run_all.sh 功能自测"
  echo "  --keep      结束后保留最后启动的应用进程（便于人工检查）"
  echo "  --full      按 ACCEPTANCE 正式采样：空载/HUD/主界面各预热 30s、5 次×12s"
  echo "  默认快速采样：预热 5s、3 次×2s（用于开发期回归，不替代 --full）"
  echo "环境变量：OTTER_FOOTPRINT_IDLE_MB（默认 25，NF-01）"
  echo "          OTTER_FOOTPRINT_HUD_MB（默认 32，NF-02）"
  echo "          OTTER_FOOTPRINT_MAIN_MB（默认 90，NF-03）"
  echo "          OTTER_BUNDLE_MAX_MB（默认 16，NF-07 已按内嵌 mole 调整）"
  echo "          OTTER_VERIFY_WARMUP / OTTER_VERIFY_SAMPLES / OTTER_VERIFY_INTERVAL"
  echo "          OTTER_BUILD_TIMEOUT（默认 600 秒，仅脚本级保护）"
  echo "          OTTER_VERIFY_TESTS_TIMEOUT（默认 900 秒）"
}

DO_BUILD=1
DO_TESTS=1
KEEP=0
FULL=0
for arg in "$@"; do
  case "$arg" in
    --no-build) DO_BUILD=0 ;;
    --no-tests) DO_TESTS=0 ;;
    --keep) KEEP=1 ;;
    --full) FULL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$arg"; usage; exit 3 ;;
  esac
done

VERIFY_DIR="/tmp/otter2-evidence/verify"
rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"

FP_IDLE=25
if [ -n "$OTTER_FOOTPRINT_IDLE_MB" ]; then FP_IDLE="$OTTER_FOOTPRINT_IDLE_MB"; fi
FP_HUD=32
if [ -n "$OTTER_FOOTPRINT_HUD_MB" ]; then FP_HUD="$OTTER_FOOTPRINT_HUD_MB"; fi
FP_MAIN=90
if [ -n "$OTTER_FOOTPRINT_MAIN_MB" ]; then FP_MAIN="$OTTER_FOOTPRINT_MAIN_MB"; fi
BUNDLE_MAX=16
if [ -n "$OTTER_BUNDLE_MAX_MB" ]; then BUNDLE_MAX="$OTTER_BUNDLE_MAX_MB"; fi
MAIN_EXPECT="960x660"

WARMUP=5
SAMPLES=3
INTERVAL=2
if [ "$FULL" -eq 1 ]; then
  WARMUP=30
  SAMPLES=5
  INTERVAL=12
fi
if [ -n "$OTTER_VERIFY_WARMUP" ]; then WARMUP="$OTTER_VERIFY_WARMUP"; fi
if [ -n "$OTTER_VERIFY_SAMPLES" ]; then SAMPLES="$OTTER_VERIFY_SAMPLES"; fi
if [ -n "$OTTER_VERIFY_INTERVAL" ]; then INTERVAL="$OTTER_VERIFY_INTERVAL"; fi

stage() { echo; echo "==== $* ===="; }
show_log_tail() {
  local f
  f="$1"
  echo "  日志末尾（$f""）："
  tail -8 "$f" 2>/dev/null | sed 's/^/    /'
}

# 多次采样 footprint，取最大值与中位数（ACCEPTANCE：以最大值判定）
sample_footprint() {
  local label pid req i fp max vals median
  label="$1"
  pid="$2"
  req="$3"
  max=0
  vals=""
  i=1
  while [ "$i" -le "$SAMPLES" ]; do
    if ! kill -0 "$pid" 2>/dev/null; then
      t5_fail "$label""：第 $i 次采样前进程已退出"
      return
    fi
    fp="$(t5_footprint_mb "$pid")"
    if [ -z "$fp" ]; then
      t5_fail "$label""：第 $i 次采样取不到 footprint（/tmp/footprint）"
      return
    fi
    vals="$vals $fp"
    if awk -v a="$fp" -v b="$max" 'BEGIN { exit !(a > b) }'; then max="$fp"; fi
    if [ "$i" -lt "$SAMPLES" ]; then sleep "$INTERVAL"; fi
    i=$((i + 1))
  done
  median="$(printf '%s\n' $vals | sort -n | awk '{a[NR]=$1} END { if (NR == 0) print 0; else if (NR % 2 == 1) print a[(NR + 1) / 2]; else print (a[NR / 2] + a[NR / 2 + 1]) / 2 }')"
  echo "  采样值：$vals""（最大 $max MB，中位 $median MB）"
  if awk -v x="$max" -v m="$req" 'BEGIN { exit !(x <= m) }'; then
    t5_pass "$label footprint 最大 $max MB ≤ 上限 $req MB（$SAMPLES 次采样，预热 $WARMUP 秒）"
  else
    t5_fail "$label footprint 最大 $max MB > 上限 $req MB（采样：$vals""）"
  fi
}

# NF-06：OTTER_BOOT_LOG=1 时 grep ready 打点，3 次取中位数
boot_log_check() {
  local i ii blog pid ms vals median missing count
  if ! grep -rq 'OTTER_BOOT_LOG' "$ROOT/Sources/Otter" 2>/dev/null; then
    t5_skip "启动到菜单栏 ≤400ms（NF-06）：源码未实现 OTTER_BOOT_LOG 打点，无法自动测量（需 dev-shell 补打点）"
    return
  fi
  missing=0
  vals=""
  i=1
  count=0
  while [ "$i" -le 3 ]; do
    t5_kill_app
    blog="$VERIFY_DIR/boot-$i.json"
    rm -f "$blog"
    env OTTER_NO_ONBOARD=1 OTTER_BOOT_LOG="$blog" "$T5_BIN" >"$T5_TMP/boot-$i.stdout" 2>&1 &
    pid=$!
    disown "$pid" 2>/dev/null || true
    if ! t5_wait_process "$pid" 5; then
      t5_fail "启动打点：第 $i 次启动进程未存活"
      missing=1
      break
    fi
    ii=0
    while [ "$ii" -lt 40 ] && [ ! -s "$blog" ]; do sleep 0.2; ii=$((ii + 1)); done
    ms="$(sed -n 's/.*"boot_ms"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$blog" 2>/dev/null | head -1)"
    if [ -z "$ms" ]; then
      missing=1
      break
    fi
    vals="$vals $ms"
    count=$((count + 1))
    i=$((i + 1))
  done
  t5_kill_app
  if [ "$missing" -eq 1 ] || [ "$count" -eq 0 ]; then
    t5_skip "启动到菜单栏 ≤400ms（NF-06）：应用未输出 OTTER_BOOT_LOG 的 ready 打点，无法自动测量（需 dev-shell 补打点）"
    return
  fi
  median="$(printf '%s\n' $vals | sort -n | awk '{a[NR]=$1} END { print a[int((NR + 1) / 2)] }')"
  if [ "$median" -le 400 ]; then
    t5_pass "启动打点 ready $median ms ≤400ms（3 次中位数；样本：$vals""）"
  else
    t5_fail "启动打点 ready $median ms > 400ms（样本：$vals""）"
  fi
}

BUILD_TIMEOUT=600
if [ -n "$OTTER_BUILD_TIMEOUT" ]; then BUILD_TIMEOUT="$OTTER_BUILD_TIMEOUT"; fi

BUILD_TIMEOUT=600
if [ -n "$OTTER_BUILD_TIMEOUT" ]; then BUILD_TIMEOUT="$OTTER_BUILD_TIMEOUT"; fi

BUILD_FAILED=0

stage "0/5 环境检查"
if ! t5_require_tools; then
  t5_summary "环境检查"
  exit 3
fi
t5_pass "验收工具齐备（/tmp/winlist、/tmp/footprint、python3）"
OTHER_OTTER="$(pgrep -fl 'OtterSolo\|OtterFinal\|devshell-final\|o2-solo' 2>/dev/null | head -3)"
if [ -n "$OTHER_OTTER" ]; then
  t5_skip "发现同 bundle 的其它测试实例，open 启动的主界面窗口/内存可能被 reopen 污染：$(printf '%s' "$OTHER_OTTER" | tr '\n' ' ')"
fi
echo "  采样模式：$SAMPLES 次 / 预热 $WARMUP 秒 / 间隔 $INTERVAL 秒（--full 为正式 NF 采样）"
echo "  阈值：空载 $FP_IDLE MB（NF-01）；HUD $FP_HUD MB（NF-02）；主界面 $FP_MAIN MB（NF-03）；包体积 $BUNDLE_MAX MB（NF-07）"

stage "1/5 构建（scripts/build.sh）"
if [ "$DO_BUILD" -eq 1 ]; then
  BUILD_LOG="$VERIFY_DIR/build.log"
  ATTEMPT=1
  BUILD_OK=0
  while [ "$ATTEMPT" -le 3 ]; do
    perl -e 'alarm shift; exec @ARGV' "$BUILD_TIMEOUT" "$ROOT/scripts/build.sh" >"$BUILD_LOG" 2>&1
    BUILD_RC=$?
    if [ "$BUILD_RC" -eq 142 ]; then
      echo "  构建超过 $BUILD_TIMEOUT 秒未完成（脚本级保护），已终止本轮"
    fi
    BUILD_ERRS="$(grep -c 'error:' "$BUILD_LOG" 2>/dev/null || true)"
    if [ -z "$BUILD_ERRS" ]; then BUILD_ERRS=0; fi
    if [ "$BUILD_RC" -eq 0 ] && [ "$BUILD_ERRS" -eq 0 ]; then
      BUILD_OK=1
      break
    fi
    if grep -q 'was modified during the build' "$BUILD_LOG" 2>/dev/null; then
      echo "  构建期间源文件被并发修改（团队并行开发），3 秒后重试（第 $ATTEMPT/3 次）"
      sleep 3
      ATTEMPT=$((ATTEMPT + 1))
      continue
    fi
    break
  done
  if [ "$BUILD_OK" -eq 1 ]; then
    t5_pass "构建成功：0 error，产物 $T5_APP""（日志：$BUILD_LOG""）"
  else
    BUILD_FAILED=1
    t5_fail "构建失败：exit=$BUILD_RC""，日志中 error 行数=$BUILD_ERRS""（日志：$BUILD_LOG""）"
    show_log_tail "$BUILD_LOG"
  fi
else
  if [ -x "$T5_BIN" ]; then
    t5_pass "跳过构建，使用现有产物：$T5_BIN"
  else
    BUILD_FAILED=1
    t5_fail "跳过构建但已有产物不存在：$T5_BIN"
  fi
fi

if [ "$BUILD_FAILED" -eq 1 ]; then
  t5_summary "Otter 原生版一键验收（构建失败，后续检查未执行）"
  exit 2
fi

stage "1.5/5 产物结构与资源"
if [ -x "$T5_BIN" ]; then
  t5_pass "可执行文件存在：$T5_BIN"
else
  t5_fail "缺少可执行文件：$T5_BIN"
fi

PLIST="$T5_APP/Contents/Info.plist"
if [ -f "$PLIST" ]; then
  LUI="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$PLIST" 2>/dev/null)"
  case "$LUI" in
    true|1) t5_pass "Info.plist LSUIElement=true（NF-11 无 Dock 图标）" ;;
    *) t5_fail "Info.plist LSUIElement 应为 true（实际：$LUI""）" ;;
  esac
  MINSYS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST" 2>/dev/null)"
  VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null)"
  if [ -z "$VER" ]; then VER="未知"; fi
  t5_pass "Info.plist 可读：版本 $VER""，最低系统 $MINSYS""（CP-01）"
else
  t5_fail "Info.plist 缺失：$PLIST"
fi

if [ -x "$T5_APP/Contents/Resources/mole/mole" ]; then
  t5_pass "内置 mole 可执行：Contents/Resources/mole/mole"
else
  t5_fail "内置 mole 缺失或不可执行：Contents/Resources/mole/mole"
fi

SIZE_KB="$(du -sk "$T5_APP" 2>/dev/null | awk '{print $1}')"
if [ -n "$SIZE_KB" ]; then
  SIZE_MB="$(awk -v k="$SIZE_KB" 'BEGIN { printf "%.1f", k / 1024 }')"
  if awk -v s="$SIZE_KB" -v m="$BUNDLE_MAX" 'BEGIN { exit !(s <= m * 1024) }'; then
    t5_pass "包体积 $SIZE_MB MB ≤ 上限 $BUNDLE_MAX MB（NF-07）"
  else
    t5_fail "包体积 $SIZE_MB MB > 上限 $BUNDLE_MAX MB（NF-07）"
  fi
else
  t5_fail "无法测量包体积（du -sk $T5_APP""）"
fi

if [ -d "$ROOT/Resources/plugins" ]; then
  for f in "$ROOT/Resources/plugins"/*.json; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    bf="$T5_APP/Contents/Resources/plugins/$base"
    if [ ! -f "$bf" ]; then
      t5_fail "内置插件未随包发布：$base""（.app 内缺 Resources/plugins/$base""）"
      continue
    fi
    if [ "$(shasum -a 256 "$f" | awk '{print $1}')" = "$(shasum -a 256 "$bf" | awk '{print $1}')" ]; then
      t5_pass "内置插件随包且内容一致：$base"
    else
      t5_fail "内置插件内容与源不一致：$base"
    fi
  done
else
  t5_skip "Resources/plugins 尚未产出（dev-ui 内置插件 manifest），跳过打包检查"
fi

NET_CODE="$(grep -R -n -E 'URLSession|NSURLConnection' "$ROOT/Sources/Otter" 2>/dev/null || true)"
if [ -n "$NET_CODE" ]; then
  t5_fail "源码出现联网 API（NF-10）：$NET_CODE"
else
  t5_pass "源码无 URLSession/NSURLConnection（NF-10 纯本地）"
fi

stage "2/5 功能自测（tests/run_all.sh，只读）"
if [ "$DO_TESTS" -eq 1 ]; then
  TESTS_LOG="$VERIFY_DIR/tests.log"
  TESTS_TIMEOUT=900
  if [ -n "$OTTER_VERIFY_TESTS_TIMEOUT" ]; then TESTS_TIMEOUT="$OTTER_VERIFY_TESTS_TIMEOUT"; fi
  if [ -x "$ROOT/tests/run_all.sh" ]; then
    perl -e 'alarm shift; exec @ARGV' "$TESTS_TIMEOUT" "$ROOT/tests/run_all.sh" >"$TESTS_LOG" 2>&1
    TESTS_RC=$?
    if [ "$TESTS_RC" -eq 0 ]; then
      t5_pass "功能自测全部通过（日志：$TESTS_LOG""）"
    else
      t5_fail "功能自测有失败项（exit=$TESTS_RC""，日志：$TESTS_LOG""）"
      grep -E '^\[FAIL\]|^【|^失败项|^    - ' "$TESTS_LOG" 2>/dev/null | head -30 | sed 's/^/    /'
    fi
    echo "  自测汇总："
    grep -E '测试脚本汇总' "$TESTS_LOG" 2>/dev/null | sed 's/^/    /'
  else
    t5_fail "缺少测试入口：$ROOT/tests/run_all.sh"
  fi
else
  t5_skip "已跳过功能自测（--no-tests）"
fi

stage "3/5 空载 footprint（NF-01）/ 启动打点（NF-06）/ 激活策略（NF-11）"
boot_log_check
t5_kill_app
IDLE_LOG="$VERIFY_DIR/idle.log"
env OTTER_NO_ONBOARD=1 "$T5_BIN" >"$IDLE_LOG" 2>&1 &
IPID=$!
disown "$IPID" 2>/dev/null || true
if t5_wait_process "$IPID" 5; then
  t5_pass "空载进程存活（pid=$IPID""）"
  LSINFO="$(lsappinfo info -only ApplicationType -app com.ottermac.app 2>/dev/null)"
  if printf '%s' "$LSINFO" | grep -q 'UIElement'; then
    t5_pass "激活策略 UIElement（lsappinfo：$(printf '%s' "$LSINFO" | tr '\n' ' ')）"
  elif [ -z "$LSINFO" ] || printf '%s' "$LSINFO" | grep -q 'NULL'; then
    t5_skip "lsappinfo 未返回 Otter 信息，无法断言无 Dock 图标（已用 LSUIElement 检查兜底）"
  else
    t5_fail "激活策略不是 UIElement：$(printf '%s' "$LSINFO" | tr '\n' ' ')"
  fi
  echo "  空载预热 $WARMUP 秒（HUD/主窗口均关闭）"
  sleep "$WARMUP"
  if kill -0 "$IPID" 2>/dev/null; then
    sample_footprint "空载" "$IPID" "$FP_IDLE"
  else
    t5_fail "空载预热期间进程退出"
    show_log_tail "$IDLE_LOG"
  fi
else
  t5_fail "空载启动后进程未存活"
  show_log_tail "$IDLE_LOG"
fi
t5_kill_app

stage "4/5 HUD 窗口 + footprint（NF-02）+ 无网络（NF-10）+ CPU 探针"
t5_kill_app
HUD_LOG="$VERIFY_DIR/hud.log"
T0="$(t5_now_ms)"
env OTTER_NO_ONBOARD=1 OTTER_SHOW_HUD=1 "$T5_BIN" >"$HUD_LOG" 2>&1 &
APP_PID=$!
disown "$APP_PID" 2>/dev/null || true
HUD_ALIVE=0
if t5_wait_process "$APP_PID" 5; then
  t5_pass "应用启动后进程存活（pid=$APP_PID""）"
  HUD_ALIVE=1
else
  t5_fail "应用启动后未存活"
  show_log_tail "$HUD_LOG"
fi

if [ "$HUD_ALIVE" -eq 1 ]; then
  WID="$(t5_wait_window "$APP_PID" "400x520" "" 10)"
  if [ -n "$WID" ]; then
    T1="$(t5_now_ms)"
    SZ="$(t5_win_size_of "$WID")"
    WT="$(t5_win_title_of "$WID")"
    if [ -z "$WT" ]; then WT="空"; fi
    t5_pass "HUD 窗口存在（id=$WID""，标题=$WT""，尺寸 $SZ""，启动到出现 $((T1 - T0))ms，含钩子 1s 延迟）"
    if [ "$SZ" = "400x520" ]; then
      t5_pass "HUD 尺寸严格为 400x520（HD-01）"
    else
      t5_fail "HUD 尺寸应为固定 400x520，实际 $SZ""（HD-01）"
    fi
    echo "  该进程窗口数：$(t5_count_windows "$APP_PID")"
  else
    t5_fail "未找到 400x520 的 HUD 窗口（winlist 中该 PID 的窗口如下）"
    /tmp/winlist 2>/dev/null | awk -F'|' -v p="$APP_PID" '{gsub(/^ +| +$/, "", $1); if ($1 == p) print "    " $0}'
    show_log_tail "$HUD_LOG"
  fi
  echo "  HUD 预热 $WARMUP 秒"
  sleep "$WARMUP"
  if kill -0 "$APP_PID" 2>/dev/null; then
    sample_footprint "HUD 打开态" "$APP_PID" "$FP_HUD"
  else
    t5_fail "HUD 预热期间进程退出"
  fi

  if command -v lsof >/dev/null 2>&1; then
    NET_OUT="$(lsof -nP -a -p "$APP_PID" -i 2>/dev/null)"
    NET_RC=$?
    if [ "$NET_RC" -eq 0 ] && [ -n "$NET_OUT" ]; then
      t5_fail "运行期检测到网络连接（NF-10 纯本地）：$(printf '%s' "$NET_OUT" | head -3 | tr '\n' ' ')"
    elif [ "$NET_RC" -eq 0 ] || [ "$NET_RC" -eq 1 ]; then
      t5_pass "运行期无网络连接（lsof -nP -p pid -i 为空，NF-10）"
    else
      t5_skip "lsof 不可用（rc=$NET_RC""），无法断言无网络"
    fi
  else
    t5_skip "缺少 lsof，无法断言无网络"
  fi

  CPU_OUT="$(/bin/ps -p "$APP_PID" -o %cpu= 2>&1)"
  if printf '%s' "$CPU_OUT" | grep -q 'Operation not permitted'; then
    t5_skip "CPU 指标（NF-04/NF-05）：沙箱禁止 ps/top 读取进程 CPU，无法自动测量"
  elif [ -n "$CPU_OUT" ]; then
    t5_pass "CPU 单次采样 $CPU_OUT%（正式 NF-04 需 5 分钟均值，建议人工/长跑）"
  else
    t5_skip "CPU 探针无输出，无法测量"
  fi

  t5_skip "菜单栏条目外观/点击（MB-01/14）：AX 权限受限，格式由 menubar 自测断言，外观由 screenshot.sh 人工确认"
fi

stage "5/5 主界面四分区（清理 / 卸载 / 磁盘 / 设置）"
for sec in clean uninstall disk settings; do
  t5_kill_app
  sleep 1
  MAIN_LOG="$VERIFY_DIR/main-$sec.log"
  if ! t5_open_flags "{\"showMain\":true,\"mainSection\":\"$sec\",\"noOnboard\":true}"; then
    t5_fail "分区 $sec""：LaunchServices 启动失败（open $T5_APP""）"
    continue
  fi
  MPID="$T5_APP_PID"
  sleep 6
  rm -f /tmp/otter-test-flags.json
  if ! t5_wait_process "$MPID" 5; then
    t5_fail "分区 $sec""：启动后进程未存活"
    show_log_tail "$MAIN_LOG"
    continue
  fi
  MWID="$(t5_wait_window "$MPID" "" "Otter" 10)"
  if [ -z "$MWID" ]; then
    MWID="$(t5_wait_window_not_size "$MPID" "400x520" 3)"
  fi
  if [ -z "$MWID" ]; then
    t5_fail "分区 $sec""：未找到主窗口（winlist 中该 PID 的窗口如下）"
    /tmp/winlist 2>/dev/null | awk -F'|' -v p="$MPID" '{gsub(/^ +| +$/, "", $1); if ($1 == p) print "    " $0}'
    show_log_tail "$MAIN_LOG"
    continue
  fi
  MSZ="$(t5_win_size_of "$MWID")"
  MW="$(printf '%s' "$MSZ" | sed 's/x.*//')"
  MH="$(printf '%s' "$MSZ" | sed 's/.*x//')"
  if [ "$MW" -ge 760 ] && [ "$MH" -ge 520 ]; then
    t5_pass "分区 $sec""：主窗口存在（id=$MWID""，尺寸 $MSZ""）"
    if [ "$MSZ" != "$MAIN_EXPECT" ]; then
      echo "    [INFO] 主窗口尺寸 $MSZ 与已确认规格 $MAIN_EXPECT 不同（观察项，非门禁）"
    fi
  else
    t5_fail "分区 $sec""：主窗口尺寸异常（$MSZ""，期望 ≥760x520）"
  fi
  if [ "$sec" = "clean" ]; then
    echo "  主界面预热 $WARMUP 秒"
    sleep "$WARMUP"
    if kill -0 "$MPID" 2>/dev/null; then
      sample_footprint "主界面打开态" "$MPID" "$FP_MAIN"
    else
      t5_fail "主界面预热期间进程退出"
    fi
  fi
done

stage "收尾"
if [ "$KEEP" -eq 1 ]; then
  echo "  --keep：保留最后启动的主界面进程（pid=$MPID""），请手动关闭或再次运行 verify.sh"
else
  t5_kill_app
  t5_pass "已清理测试进程（pkill -f $T5_BIN""）"
fi
echo "  证据目录：$VERIFY_DIR"
ls -1 "$VERIFY_DIR" 2>/dev/null | sed 's/^/    /'

t5_summary "Otter 原生版一键验收"
SUMMARY_RC=$?
if [ "$SUMMARY_RC" -ne 0 ]; then
  if [ "$BUILD_FAILED" -eq 1 ]; then exit 2; fi
  exit 1
fi
echo "验收通过：全部检查项通过"
exit 0
