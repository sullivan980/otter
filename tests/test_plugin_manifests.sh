#!/bin/bash
# T5 · 内置插件 manifest 静态校验 + 是否随 .app 发布（只读）
set -o pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

echo "== 内置插件 manifest（n1/n8） =="
SRC="$T5_ROOT/Resources/plugins"
if [ ! -d "$SRC" ]; then
  t5_skip "Resources/plugins 尚未产出（dev-ui 内置插件 manifest），跳过静态校验与打包检查"
  t5_summary "内置插件 manifest"
  exit 0
fi

FILES="$(ls "$SRC"/*.json 2>/dev/null | wc -l | tr -d ' ')"
if [ "$FILES" -eq 0 ]; then
  t5_fail "Resources/plugins 目录存在但没有 .json 文件"
else
  t5_pass "Resources/plugins 下有 $FILES 个 manifest 文件"
  t5_check_output "manifest-src" "$DIR/checks/manifest_check.py" "$SRC"
fi

if [ ! -x "$T5_BIN" ]; then
  t5_fail "构建产物不存在，无法验证内置插件是否随 .app 发布（先运行 scripts/build.sh）"
else
  for f in "$SRC"/*.json; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    bf="$T5_APP/Contents/Resources/plugins/$base"
    if [ ! -f "$bf" ]; then
      t5_fail "内置插件未随包发布：$base""（.app 内缺 Resources/plugins/$base""，build.sh 拷贝缺失）"
      continue
    fi
    src_sum="$(shasum -a 256 "$f" | awk '{print $1}')"
    dst_sum="$(shasum -a 256 "$bf" | awk '{print $1}')"
    if [ "$src_sum" = "$dst_sum" ]; then
      t5_pass "内置插件随包且内容一致：$base"
    else
      t5_fail "内置插件随包但内容不一致：$base""（源 $src_sum / 包 $dst_sum""）"
    fi
  done
fi

t5_summary "内置插件 manifest"
exit $?
