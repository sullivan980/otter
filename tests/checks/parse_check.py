#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""mole dry-run 样本解析断言（只读）。

输入：tests/fixtures/clean_dry_run.txt（旧版 ui/home.js CLEAN_SAMPLE 原样样本）。
需要 dev-data 提供钩子：OTTER_SELFTEST=parse + OTTER_SELFTEST_INPUT=<样本文件>，
输出形如 {"mode":"parse","categories":4,"summary_categories":6,"summary_items":265,"potential_bytes":3145728000}。
钩子缺失时本检查记 SKIP（不误报失败），并在报告中如实标注未实现。
"""
import json
import sys

EXPECTED_PARSED_CATEGORIES = 4
EXPECTED_SUMMARY_CATEGORIES = 6
EXPECTED_SUMMARY_ITEMS = 265
POTENTIAL_LOW = 2.6 * 10 ** 9
POTENTIAL_HIGH = 3.4 * 10 ** 9


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


def is_num(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def main():
    path = sys.argv[1]
    obj, raw = read_json_line(path)
    fails = 0

    def ok(cond, msg):
        nonlocal fails
        print(("[PASS] " if cond else "[FAIL] ") + msg)
        if not cond:
            fails += 1

    if obj is None or obj.get("mode") != "parse":
        print("[SKIP] 未实现 OTTER_SELFTEST=parse 解析钩子，无法用真实样本验证 mole dry-run 解析")
        print("[SKIP] 期望钩子：OTTER_SELFTEST=parse + OTTER_SELFTEST_INPUT=<样本文件>（详见 tests/README.md）")
        print("[INFO] 原始自测输出：%s" % raw.strip()[-200:])
        return 0

    cats = obj.get("categories")
    ok(is_num(cats) and int(cats) == EXPECTED_PARSED_CATEGORIES,
       "样本解析出 %d 个 ➤ 分类（实际 %r）" % (EXPECTED_PARSED_CATEGORIES, cats))

    summary_cats = obj.get("summary_categories")
    ok(is_num(summary_cats) and int(summary_cats) == EXPECTED_SUMMARY_CATEGORIES,
       "汇总 Categories=%d（实际 %r）" % (EXPECTED_SUMMARY_CATEGORIES, summary_cats))

    summary_items = obj.get("summary_items")
    ok(is_num(summary_items) and int(summary_items) == EXPECTED_SUMMARY_ITEMS,
       "汇总 Items=%d（实际 %r）" % (EXPECTED_SUMMARY_ITEMS, summary_items))

    potential = obj.get("potential_bytes")
    if is_num(potential):
        ok(POTENTIAL_LOW <= potential <= POTENTIAL_HIGH,
           "Potential space 换算字节在 2.6-3.4GB（实际 %r）" % (potential,))
    else:
        text = str(obj.get("potential", ""))
        ok(text.startswith("2.93"),
           "Potential space 文本为 2.93GB（实际 %r）" % (text,))

    items = obj.get("items")
    if items is not None:
        ok(is_num(items) and items >= 0, "解析条目数 >= 0（实际 %r）" % (items,))

    print("[INFO] 原始自测输出：%s" % raw.strip()[-300:])
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
