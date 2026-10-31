#!/bin/bash
# T5 · OTTER_SELFTEST=uninstall 断言（只读扫描，不删除任何应用）
set -o pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

echo "== OTTER_SELFTEST=uninstall（应用列表 + 残留结构） =="
t5_require_bin

TIMEOUT=180
if [ -n "$OTTER_SELFTEST_UNINSTALL_TIMEOUT" ]; then TIMEOUT="$OTTER_SELFTEST_UNINSTALL_TIMEOUT"; fi

T0="$(t5_now_ms)"
if t5_run_selftest uninstall "$TIMEOUT"; then
  T1="$(t5_now_ms)"
  echo "  扫描耗时 $((T1 - T0)) ms"
  t5_check_output "uninstall" "$DIR/checks/uninstall_check.py" "$T5_ST_OUT"
fi
echo "  输出摘要：$(tail -2 "$T5_ST_OUT" 2>/dev/null | tr '\n' ' ')"
t5_summary "uninstall 自测"
exit $?
