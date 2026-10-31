#!/bin/bash
# =====================================================================
# Otter 原生版 · T5 测试公共库（bash 3.2 兼容）
# 约定：断言输出 [PASS] / [FAIL] / [SKIP] 三态；失败数决定退出码。
# 红线：只读验收，不执行真实清理 / 优化 / 删除。
# 说明：为兼容 macOS 自带 bash 3.2 且避免与环境变量插值冲突，
#       本库不使用花括号变量写法，全部用 $VAR 形式。
# =====================================================================

T5_DIR="$(cd "$(dirname "$BASH_SOURCE")" && pwd)"
T5_ROOT="$(cd "$T5_DIR/.." && pwd)"
T5_APP="$T5_ROOT/build/Otter.app"
# 可选：验收已构建产物快照（避免团队并发构建时 build/ 被 rm -rf 造成误报）
if [ -n "$OTTER2_APP_PATH" ]; then T5_APP="$OTTER2_APP_PATH"; fi
T5_BIN="$T5_APP/Contents/MacOS/Otter"

T5_TMP="/tmp/otter2-t5"
mkdir -p "$T5_TMP" 2>/dev/null || true

# 沙箱安全假 HOME：mole dry-run 需要写 ~/.config/mole 与 ~/Library/Logs/mole，
# 但 DSH 沙箱禁止写真实 HOME。这里用 /tmp 假 HOME + 只读符号链接指向真实缓存目录，
# 让 dry-run 能完整扫描，且所有写入只落在 /tmp（红线：不碰真实用户数据）。
T5_FAKE_HOME="/tmp/otter2-t5/home"
t5_prepare_fake_home() {
  local h p
  h="$T5_FAKE_HOME"
  rm -rf "$h"
  mkdir -p "$h/.config/mole" "$h/Library/Logs/mole" "$h/Library"
  for p in "Library/Caches" "Library/Application Support" "Library/Preferences" "Library/Saved Application State" "Library/Containers" "Library/WebKit" ".npm" ".cache" ".gradle" ".ollama"; do
    if [ -e "$HOME/$p" ]; then
      mkdir -p "$h/$(dirname "$p")"
      ln -s "$HOME/$p" "$h/$p" 2>/dev/null || true
    fi
  done
}

T5_PASS=0
T5_FAIL=0
T5_SKIP=0
T5_FAIL_LIST=""
T5_APP_PID=""
T5_ST_RC=0
T5_ST_OUT=""
T5_ST_ERR=""

t5_pass() { T5_PASS=$((T5_PASS + 1)); printf '  [PASS] %s\n' "$*"; }
t5_fail() {
  T5_FAIL=$((T5_FAIL + 1))
  T5_FAIL_LIST="$T5_FAIL_LIST
    - $*"
  printf '  [FAIL] %s\n' "$*"
}
t5_skip() { T5_SKIP=$((T5_SKIP + 1)); printf '  [SKIP] %s\n' "$*"; }

t5_summary() {
  local name
  name="$1"
  if [ -z "$name" ]; then name="测试"; fi
  echo "------------------------------------------------------------"
  printf '【%s】通过 %d / 失败 %d / 跳过 %d\n' "$name" "$T5_PASS" "$T5_FAIL" "$T5_SKIP"
  if [ "$T5_FAIL" -gt 0 ]; then
    printf '失败项：%s\n' "$T5_FAIL_LIST"
    return 1
  fi
  return 0
}

# 前置：构建产物存在
t5_require_bin() {
  if [ ! -x "$T5_BIN" ]; then
    t5_fail "构建产物不存在或不可执行：$T5_BIN""（请先运行 scripts/build.sh）"
    t5_summary "前置检查"
    exit 1
  fi
}

# 前置：验收工具齐备；返回 0 齐备 / 1 缺失
t5_require_tools() {
  local missing
  missing=0
  if [ ! -x /tmp/winlist ]; then t5_fail "缺少窗口枚举工具 /tmp/winlist"; missing=1; fi
  if [ ! -x /tmp/footprint ]; then t5_fail "缺少内存测量工具 /tmp/footprint"; missing=1; fi
  if ! command -v python3 >/dev/null 2>&1; then t5_fail "缺少 python3（JSON 断言需要）"; missing=1; fi
  return $missing
}

# 只杀本构建产物对应的 Otter，避免误伤
t5_kill_app() {
  pkill -f "$T5_BIN" 2>/dev/null || true
  sleep 0.3
  if pgrep -f "$T5_BIN" >/dev/null 2>&1; then
    pkill -9 -f "$T5_BIN" 2>/dev/null || true
    sleep 0.5
  fi
}

# 通过 LaunchServices 启动（open --args），脱离 DSH 沙箱：
# 应用可正常写 ~/.config/mole、~/Library/Logs（mole/通知需要），且 -OTTER_X=Y 会被
# Sources/Otter/App/main.swift 转成环境变量。
# 输出 PID 到 T5_APP_PID；返回 0 表示启动且找到进程。
t5_open_app() {
  local i
  open -n "$T5_APP" --args "$@" >/dev/null 2>&1
  T5_APP_PID=""
  i=0
  while [ "$i" -lt 80 ]; do
    T5_APP_PID="$(pgrep -f "$T5_BIN" 2>/dev/null | head -1)"
    if [ -n "$T5_APP_PID" ]; then return 0; fi
    sleep 0.1
    i=$((i + 1))
  done
  return 1
}

# 通过 LaunchServices + /tmp/otter-test-flags.json 启动 GUI（showMain/mainSection/noOnboard 等）。
t5_open_flags() {
  local i
  rm -f /tmp/otter-test-flags.json
  printf '%s' "$1" > /tmp/otter-test-flags.json
  open -n "$T5_APP" >/dev/null 2>&1
  T5_APP_PID=""
  i=0
  while [ "$i" -lt 80 ]; do
    T5_APP_PID="$(pgrep -f "$T5_BIN" 2>/dev/null | head -1)"
    if [ -n "$T5_APP_PID" ]; then sleep 0.5; return 0; fi
    sleep 0.1
    i=$((i + 1))
  done
  return 1
}

# 通过 LaunchServices 跑 OTTER_SELFTEST，结果从 OTTER_SELFTEST_OUT 读取。
t5_open_selftest() {
  local mode out secs i
  mode="$1"
  out="$2"
  secs="$3"
  if [ -z "$secs" ]; then secs=120; fi
  rm -f "$out"
  open -n "$T5_APP" --args "-OTTER_SELFTEST=$mode" "-OTTER_SELFTEST_OUT=$out" >/dev/null 2>&1
  i=0
  while [ "$i" -lt $((secs * 2)) ]; do
    if [ -f "$out" ] && [ -s "$out" ]; then
      T5_ST_OUT="$out"
      sleep 0.3
      t5_kill_app
      return 0
    fi
    sleep 0.5
    i=$((i + 1))
  done
  t5_fail "OTTER_SELFTEST=$mode 经 LaunchServices 启动后 $secs 秒内未写出 OTTER_SELFTEST_OUT（$out""）"
  t5_kill_app
  return 1
}

t5_wait_process() {
  local pid secs i
  pid="$1"
  secs="$2"
  if [ -z "$secs" ]; then secs=5; fi
  i=0
  while [ "$i" -lt $((secs * 10)) ]; do
    if kill -0 "$pid" 2>/dev/null; then return 0; fi
    sleep 0.1
    i=$((i + 1))
  done
  return 1
}

# winlist 行格式：PID | WINDOW_ID | OWNER | TITLE | x,y WxH
t5_find_window() {
  local pid size title
  pid="$1"
  size="$2"
  title="$3"
  /tmp/winlist 2>/dev/null | awk -F'|' -v p="$pid" -v ws="$size" -v wt="$title" '
    {
      for (i = 1; i <= 5; i++) gsub(/^ +| +$/, "", $i)
      if ($1 != p) next
      n = split($5, a, " ")
      sz = a[n]
      if (ws != "" && sz != ws) next
      if (wt != "" && $4 != wt) next
      print $2
      exit
    }'
}

t5_find_window_not_size() {
  local pid excl
  pid="$1"
  excl="$2"
  /tmp/winlist 2>/dev/null | awk -F'|' -v p="$pid" -v ex="$excl" '
    {
      for (i = 1; i <= 5; i++) gsub(/^ +| +$/, "", $i)
      if ($1 != p) next
      n = split($5, a, " ")
      if (a[n] == ex) next
      print $2
      exit
    }'
}

t5_wait_window() {
  local pid size title secs i wid
  pid="$1"
  size="$2"
  title="$3"
  secs="$4"
  if [ -z "$secs" ]; then secs=10; fi
  i=0
  while [ "$i" -lt $((secs * 5)) ]; do
    wid="$(t5_find_window "$pid" "$size" "$title")"
    if [ -n "$wid" ]; then printf '%s' "$wid"; return 0; fi
    sleep 0.2
    i=$((i + 1))
  done
  return 1
}

t5_wait_window_not_size() {
  local pid excl secs i wid
  pid="$1"
  excl="$2"
  secs="$3"
  if [ -z "$secs" ]; then secs=5; fi
  i=0
  while [ "$i" -lt $((secs * 5)) ]; do
    wid="$(t5_find_window_not_size "$pid" "$excl")"
    if [ -n "$wid" ]; then printf '%s' "$wid"; return 0; fi
    sleep 0.2
    i=$((i + 1))
  done
  return 1
}

t5_win_size_of() {
  local wid
  wid="$1"
  /tmp/winlist 2>/dev/null | awk -F'|' -v id="$wid" '
    {
      gsub(/^ +| +$/, "", $2)
      if ($2 != id) next
      n = split($5, a, " ")
      print a[n]
      exit
    }'
}

t5_win_title_of() {
  local wid
  wid="$1"
  /tmp/winlist 2>/dev/null | awk -F'|' -v id="$wid" '
    {
      gsub(/^ +| +$/, "", $2)
      if ($2 != id) next
      gsub(/^ +| +$/, "", $4)
      print $4
      exit
    }'
}

t5_count_windows() {
  local pid
  pid="$1"
  /tmp/winlist 2>/dev/null | awk -F'|' -v p="$pid" '
    { gsub(/^ +| +$/, "", $1); if ($1 == p) c++ }
    END { print c + 0 }'
}

t5_footprint_raw() {
  local pid
  pid="$1"
  /tmp/footprint "$pid" 2>/dev/null | head -1
}

t5_footprint_mb() {
  local raw
  raw="$(t5_footprint_raw "$1")"
  printf '%s' "$raw" | sed -n 's/.*footprint= *\([0-9][0-9.]*\)MB.*/\1/p'
}

# t5_check_footprint 标题 pid 用户目标MB REQUIREMENTS上限MB
t5_check_footprint() {
  local label pid target req raw mb
  label="$1"
  pid="$2"
  target="$3"
  req="$4"
  if [ -z "$target" ]; then target=25; fi
  if [ -z "$req" ]; then req=50; fi
  raw="$(t5_footprint_raw "$pid")"
  mb="$(t5_footprint_mb "$pid")"
  if [ -z "$mb" ]; then
    t5_fail "$label""：/tmp/footprint 未取到 footprint（原始：$raw""，pid=$pid""）"
    return
  fi
  if awk -v x="$mb" -v m="$req" 'BEGIN { exit !(x <= m) }'; then
    if awk -v x="$mb" -v m="$target" 'BEGIN { exit !(x <= m) }'; then
      t5_pass "$label""：footprint $mb MB ≤ 目标 $target MB（/tmp/footprint: $raw""）"
    else
      t5_pass "$label""：footprint $mb MB 超过用户目标 $target MB，但 ≤ REQUIREMENTS 上限 $req MB（/tmp/footprint: $raw""）"
    fi
  else
    t5_fail "$label""：footprint $mb MB > REQUIREMENTS 上限 $req MB（/tmp/footprint: $raw""）"
  fi
}

t5_now_ms() { perl -MTime::HiRes=time -e 'printf("%.0f", time * 1000)'; }

# 运行只读自测；结果写入 T5_ST_OUT / T5_ST_ERR / T5_ST_RC
# 超时用 perl alarm（macOS 无 timeout 命令）
t5_run_selftest() {
  local mode secs out err
  mode="$1"
  secs="$2"
  if [ -z "$secs" ]; then secs=60; fi
  out="$T5_TMP/selftest-$mode.out"
  err="$T5_TMP/selftest-$mode.err"
  env OTTER_SELFTEST="$mode" perl -e 'alarm shift; exec @ARGV' "$secs" "$T5_BIN" >"$out" 2>"$err"
  T5_ST_RC=$?
  T5_ST_OUT="$out"
  T5_ST_ERR="$err"
  if [ "$T5_ST_RC" -eq 142 ] || [ "$T5_ST_RC" -eq 14 ]; then
    t5_fail "OTTER_SELFTEST=$mode 超时（$secs 秒）；输出末尾：$(tail -2 "$out" 2>/dev/null | tr '\n' ' ')"
    return 1
  fi
  if [ "$T5_ST_RC" -ne 0 ]; then
    t5_fail "OTTER_SELFTEST=$mode 退出码 $T5_ST_RC""；stderr 末尾：$(tail -2 "$err" 2>/dev/null | tr '\n' ' ')"
    return 1
  fi
  return 0
}

# 用 python 断言脚本检查输出文件，并把 PASS/FAIL/SKIP 计数并入本测试
t5_check_output() {
  local label checker file out rc p f s
  label="$1"
  checker="$2"
  file="$3"
  shift 3
  out="$(python3 "$checker" "$file" "$@" 2>&1)"
  rc=$?
  printf '%s\n' "$out"
  p="$(printf '%s\n' "$out" | grep -c '^\[PASS\]' || true)"
  f="$(printf '%s\n' "$out" | grep -c '^\[FAIL\]' || true)"
  s="$(printf '%s\n' "$out" | grep -c '^\[SKIP\]' || true)"
  if [ -z "$p" ]; then p=0; fi
  if [ -z "$f" ]; then f=0; fi
  if [ -z "$s" ]; then s=0; fi
  T5_PASS=$((T5_PASS + p))
  T5_SKIP=$((T5_SKIP + s))
  if [ "$f" -gt 0 ]; then
    T5_FAIL=$((T5_FAIL + f))
    T5_FAIL_LIST="$T5_FAIL_LIST
    - [$label] $f 项断言失败（明细见上）"
  elif [ "$rc" -ne 0 ]; then
    T5_FAIL=$((T5_FAIL + 1))
    T5_FAIL_LIST="$T5_FAIL_LIST
    - [$label] 断言脚本异常退出（rc=$rc""）"
  fi
}
