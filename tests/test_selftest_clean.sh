#!/bin/bash
# T5 · OTTER_SELFTEST=clean dry-run 解析断言（只读，绝不真实清理）
#
# 沙箱适配（确定性模式）：DSH 沙箱禁止写真实 HOME，而 mole dry-run 必须写
# ~/.config/mole/clean-list.txt 与 ~/Library/Logs/mole/operations.log。
# 这里临时把 HOME 指向 /tmp/otter2-t5/home（内部用只读符号链接指向真实缓存目录），
# dry-run 可完整扫描且所有写入只落在 /tmp；应用侧只跑 clean --dry-run。
# 说明：open --args 跨沙盒模式在当前环境受同 bundle 实例/reopen 干扰，故 clean 采用直启。
set -o pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

echo "== OTTER_SELFTEST=clean（mole dry-run 分类解析，直启 + 沙箱安全 HOME） =="
t5_require_bin

TIMEOUT=300
if [ -n "$OTTER_SELFTEST_CLEAN_TIMEOUT" ]; then TIMEOUT="$OTTER_SELFTEST_CLEAN_TIMEOUT"; fi

t5_prepare_fake_home
REAL_HOME="$HOME"
export HOME="$T5_FAKE_HOME"
echo "  dry-run HOME=$HOME""（符号链接只读指向真实缓存；写入仅落 /tmp）"

T0="$(t5_now_ms)"
if t5_run_selftest clean "$TIMEOUT"; then
  T1="$(t5_now_ms)"
  echo "  dry-run 耗时 $((T1 - T0)) ms"
  t5_check_output "clean" "$DIR/checks/clean_check.py" "$T5_ST_OUT"
fi
export HOME="$REAL_HOME"
echo "  输出摘要：$(tail -2 "$T5_ST_OUT" 2>/dev/null | tr '\n' ' ')"
t5_summary "clean dry-run 自测"
exit $?
