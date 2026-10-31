#!/bin/bash
# T5 · OTTER_SELFTEST=menubar 菜单栏格式断言（只读，无需 AX 权限）
set -o pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

echo "== OTTER_SELFTEST=menubar（格式规范：不补零 / 单位 / 空态回退） =="
t5_require_bin
if t5_run_selftest menubar 30; then
  t5_check_output "menubar" "$DIR/checks/menubar_check.py" "$T5_ST_OUT"
fi
echo "  输出摘要：$(tail -2 "$T5_ST_OUT" 2>/dev/null | tr '\n' ' ')"
t5_summary "menubar 格式"
exit $?
