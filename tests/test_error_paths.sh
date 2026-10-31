#!/bin/bash
# T5 · 错误路径只读测试：非法插件 manifest / 空插件目录 / 不存在目录 / 空删除列表
set -o pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

echo "== 错误路径（全部只读；临时目录 + 拒绝路径，不删除任何真实文件） =="
t5_require_bin

# 1) 非法插件 manifest（坏 JSON）
BADDIR="$T5_TMP/plugins-bad"
rm -rf "$BADDIR"
mkdir -p "$BADDIR"
printf '{"id": "bad", "rows": [' > "$BADDIR/bad.json"
export OTTER_PLUGIN_DIR="$BADDIR"
if t5_run_selftest plugins 30; then
  t5_check_output "plugins/非法manifest" "$DIR/checks/plugins_check.py" "$T5_ST_OUT" "$BADDIR" reject-bad
fi
unset OTTER_PLUGIN_DIR

# 2) 空插件目录
EMPTYDIR="$T5_TMP/plugins-empty"
rm -rf "$EMPTYDIR"
mkdir -p "$EMPTYDIR"
export OTTER_PLUGIN_DIR="$EMPTYDIR"
if t5_run_selftest plugins 30; then
  t5_check_output "plugins/空目录" "$DIR/checks/plugins_check.py" "$T5_ST_OUT" "$EMPTYDIR" empty-ok
fi
unset OTTER_PLUGIN_DIR

# 3) 不存在的插件目录
MISSINGDIR="$T5_TMP/plugins-not-exist"
rm -rf "$MISSINGDIR"
export OTTER_PLUGIN_DIR="$MISSINGDIR"
if t5_run_selftest plugins 30; then
  t5_check_output "plugins/不存在目录" "$DIR/checks/plugins_check.py" "$T5_ST_OUT" "$MISSINGDIR" missing-dir-ok
fi
unset OTTER_PLUGIN_DIR

# 4) 空删除列表守护（不传入任何真实文件）
if t5_run_selftest trash-empty 30; then
  t5_check_output "uninstall/空删除列表" "$DIR/checks/trash_check.py" "$T5_ST_OUT"
fi

t5_summary "错误路径"
exit $?
