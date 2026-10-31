#!/bin/bash
# T5 · OTTER_SELFTEST=metrics 断言（只读）
set -o pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

echo "== OTTER_SELFTEST=metrics（CPU/内存/磁盘/网络） =="
t5_require_bin
if t5_run_selftest metrics 30; then
  t5_check_output "metrics" "$DIR/checks/metrics_check.py" "$T5_ST_OUT"
fi
echo "  输出摘要：$(tail -2 "$T5_ST_OUT" 2>/dev/null | tr '\n' ' ')"
t5_summary "metrics 自测"
exit $?
