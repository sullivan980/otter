#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OTTER_SELFTEST=menubar 输出断言（只读，无需 AX 权限）。

实际输出（MenuBarFormat.selfTestJSON）：6 个字符串字段
dual / zero / full / net / reordered / empty。
断言：无前导零、0%/100% 边界、速率带单位、空态回退 Otter、reordered 顺序生效。
"""
import json
import re
import sys

LEADING_ZERO = re.compile(r"(?<![0-9])0[0-9]+%")
RATE = re.compile(r"[0-9]+(?:\.[0-9]+)?(?:B|K|M|G)/s")


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


def text_of(obj, key):
    value = obj.get(key, "")
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return " ".join(str(v) for v in value.values())
    if isinstance(value, list):
        return " ".join(str(v) for v in value)
    return str(value)


def main():
    path = sys.argv[1]
    obj, raw = read_json_line(path)
    fails = 0

    def ok(cond, msg):
        nonlocal fails
        print(("[PASS] " if cond else "[FAIL] ") + msg)
        if not cond:
            fails += 1

    if obj is None or obj.get("mode") != "menubar":
        print("[SKIP] 未实现 OTTER_SELFTEST=menubar 钩子，无法自动化断言菜单栏格式")
        print("[INFO] 原始自测输出：%s" % raw.strip()[-200:])
        return 0

    fields = ["dual", "zero", "full", "net", "reordered", "empty"]
    texts = {field: text_of(obj, field) for field in fields}
    all_text = " ".join(texts.values())

    bad_zero = LEADING_ZERO.findall(all_text)
    ok(not bad_zero, "菜单栏文本无前导零（违规：%r）" % (bad_zero,))
    ok("0%" in texts["zero"], "zero 场景显示 0%%（实际：%r）" % (texts["zero"],))
    ok("00%" not in texts["zero"], "zero 场景不出现 00%%（实际：%r）" % (texts["zero"],))
    ok("100%" in texts["full"], "full 场景显示 100%%（实际：%r）" % (texts["full"],))
    ok(bool(RATE.search(texts["net"])), "网络速率带单位（实际：%r）" % (texts["net"],))
    ok("Otter" in texts["empty"], '空数据回退显示 "Otter"（实际：%r）' % (texts["empty"],))

    dual_parts = texts["dual"].split()
    reordered_parts = texts["reordered"].split()
    ok(bool(reordered_parts), "reordered 场景有输出（实际：%r）" % (texts["reordered"],))
    if dual_parts and reordered_parts:
        ok(reordered_parts == list(reversed(dual_parts)),
           "reordered 顺序与 dual 相反（dual=%r / reordered=%r）" % (texts["dual"], texts["reordered"]))

    print("[INFO] 原始自测输出：%s" % raw.strip()[-400:])
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
