#!/bin/bash
# T5 · mole dry-run 只读样本解析断言（对照旧版 otter/ui/home.js CLEAN_SAMPLE）
set -o pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

echo "== mole dry-run 样本解析（fixtures/clean_dry_run.txt） =="
t5_require_bin

FIXTURE="$DIR/fixtures/clean_dry_run.txt"
if [ ! -f "$FIXTURE" ]; then
  t5_fail "缺少解析样本：$FIXTURE"
  t5_summary "mole 样本解析"
  exit 1
fi
echo "  样本来源：旧版 otter/ui/home.js 的 CLEAN_SAMPLE（真实 dry-run 输出子集，只读）"

export OTTER_SELFTEST_INPUT="$FIXTURE"
if t5_run_selftest parse 60; then
  t5_check_output "mole-parse" "$DIR/checks/parse_check.py" "$T5_ST_OUT"
fi
unset OTTER_SELFTEST_INPUT

echo "  输出摘要：$(tail -2 "$T5_ST_OUT" 2>/dev/null | tr '\n' ' ')"
t5_summary "mole 样本解析"
exit $?
