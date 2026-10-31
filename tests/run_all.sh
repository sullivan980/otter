#!/bin/bash
# T5 · 运行全部测试脚本（每个脚本独立可执行，也可单独跑）
set -o pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

LIST="test_selftest_metrics.sh test_selftest_clean.sh test_selftest_uninstall.sh test_mole_parse.sh test_menubar.sh test_plugin_manifests.sh test_error_paths.sh"
if [ "$#" -gt 0 ]; then LIST="$*"; fi

PASSED=0
FAILED=0
FAILED_LIST=""
for s in $LIST; do
  echo
  echo "=================================================================="
  echo "  运行 $s"
  echo "=================================================================="
  if [ ! -x "$DIR/$s" ]; then
    echo "  [FAIL] 测试脚本不存在或不可执行：$DIR/$s"
    FAILED=$((FAILED + 1))
    FAILED_LIST="$FAILED_LIST
    - $s""（缺失）"
    continue
  fi
  if "$DIR/$s"; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    FAILED_LIST="$FAILED_LIST
    - $s"
  fi
done

echo
echo "=================================================================="
printf '测试脚本汇总：通过 %d / 失败 %d\n' "$PASSED" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
  printf '失败脚本：%s\n' "$FAILED_LIST"
  exit 1
fi
echo "全部测试脚本通过"
exit 0
