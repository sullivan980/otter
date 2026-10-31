#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""插件 manifest 加载错误路径断言（只读）。

用法：plugins_check.py <自测输出文件> <插件目录> <期望: reject-bad|empty-ok|missing-dir-ok>
实际输出（dev-ui）：{"mode":"plugins","valid":["n1"],"rejected":["{\"file\":\"bad.json\",\"error\":\"...\"}"]}
（rejected 元素是 JSON 字符串，本脚本会归一化为对象再断言。）
"""
import json
import os
import re
import sys


def read_json_line(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            raw = fh.read()
    except OSError as exc:
        print("[FAIL] 无法读取自测输出：%s" % exc)
        return None, ""
    for line in reversed(raw.splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line), raw
            except json.JSONDecodeError:
                continue
    return None, raw


def normalize_rejections(items):
    out = []
    for item in items:
        if isinstance(item, dict):
            out.append(item)
            continue
        text = str(item)
        parsed = None
        try:
            parsed = json.loads(text)
        except Exception:
            parsed = None
        if isinstance(parsed, dict):
            out.append(parsed)
            continue
        mf = re.search(r'"file"\s*:\s*"([^"]*)"', text)
        me = re.search(r'"error"\s*:\s*"([^"]*)"', text)
        out.append({
            "file": mf.group(1) if mf else text,
            "error": me.group(1) if me else "",
        })
    return out


def main():
    path = sys.argv[1]
    plugin_dir = sys.argv[2] if len(sys.argv) > 2 else ""
    expect = sys.argv[3] if len(sys.argv) > 3 else "reject-bad"
    obj, raw = read_json_line(path)
    fails = 0

    def ok(cond, msg):
        nonlocal fails
        print(("[PASS] " if cond else "[FAIL] ") + msg)
        if not cond:
            fails += 1

    if obj is None or obj.get("mode") != "plugins":
        print("[SKIP] 未实现 OTTER_SELFTEST=plugins 钩子，无法验证非法/空/不存在插件目录的错误路径")
        print("[SKIP] 期望钩子：OTTER_SELFTEST=plugins + OTTER_PLUGIN_DIR=<目录>（详见 tests/README.md）")
        print("[INFO] 原始自测输出：%s" % raw.strip()[-200:])
        return 0

    valid = obj.get("valid", [])
    rejected = normalize_rejections(obj.get("rejected", []))
    if not isinstance(valid, list):
        valid = []

    if expect == "reject-bad":
        names = [os.path.basename(str(item.get("file", ""))) for item in rejected]
        ok("bad.json" in names, "非法 manifest bad.json 被拒绝（rejected=%r）" % (names,))
        ok(all(str(item.get("error", "")).strip() for item in rejected),
           "拒绝记录带非空 error 说明（rejected=%r）" % (rejected,))
        ok(all("bad" not in str(v).lower() for v in valid),
           "非法 manifest 未进入有效列表（valid=%r）" % (valid,))
    elif expect == "empty-ok":
        ok(valid == [] and rejected == [],
           "空插件目录不崩溃且不产出插件（valid=%r, rejected=%r）" % (valid, rejected))
    elif expect == "missing-dir-ok":
        ok(valid == [] and rejected == [],
           "不存在的插件目录不崩溃（valid=%r, rejected=%r）" % (valid, rejected))
    else:
        ok(False, "未知期望类型：%s" % expect)

    print("[INFO] 原始自测输出：%s" % raw.strip()[-300:])
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
