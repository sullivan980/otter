#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OTTER_SELFTEST=clean 输出断言（只读 dry-run 结果）。

实际输出字段（dev-data）：mode / ok / categories / nonEmptyCategories /
items / totalBytes / duration_ms / summary_* / categories_detail。
判定：ok=true、分类数>0、总大小>=0。
"""
import json
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


def is_num(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def pick(obj, keys):
    for key in keys:
        if key in obj:
            return key, obj[key]
    return None, None


def main():
    path = sys.argv[1]
    obj, raw = read_json_line(path)
    fails = 0

    def ok(cond, msg):
        nonlocal fails
        print(("[PASS] " if cond else "[FAIL] ") + msg)
        if not cond:
            fails += 1

    if obj is None:
        print("[FAIL] clean 自测输出不是合法 JSON；原始输出末尾：")
        print(raw[-400:])
        return 1

    ok(obj.get("mode") == "clean", 'mode 必须为 "clean"（实际：%r）' % (obj.get("mode"),))
    if "ok" in obj:
        ok(obj.get("ok") is True, "dry-run 成功 ok=true（error：%r）" % (obj.get("error"),))

    cats_key, cats = pick(obj, ["categories", "cats", "category_count"])
    if cats_key is None:
        print("[FAIL] 缺少分类数字段（categories/cats/category_count）")
        if obj.get("error"):
            print("[FAIL] 自测错误：%s" % obj.get("error"))
        print("[INFO] 原始自测输出：%s" % raw.strip()[-300:])
        fails += 1
    else:
        ok(is_num(cats) and cats > 0, "分类数 > 0（字段 %s，实际 %r）" % (cats_key, cats))

    total_key, total = pick(obj, ["totalBytes", "total_bytes", "total_size", "total"])
    if total_key is None:
        print("[FAIL] 缺少总大小字段（totalBytes/total_bytes/total_size/total）")
        fails += 1
    else:
        ok(is_num(total) and total >= 0, "可清理总大小 >= 0（字段 %s，实际 %r）" % (total_key, total))
        if is_num(total):
            ok(total < 20 * 1024 ** 4, "总大小在合理范围（<20TB，实际 %r）" % (total,))

    items_key, items = pick(obj, ["items", "item_count"])
    if items_key is not None and is_num(items):
        ok(items >= 0, "条目数 >= 0（字段 %s，实际 %r）" % (items_key, items))

    detail = obj.get("categories_detail")
    if isinstance(detail, list) and detail:
        first = detail[0]
        ok(isinstance(first, dict) and isinstance(first.get("title"), str) and first.get("title"),
           "分类明细含 title（首项：%r）" % (first,))
    else:
        print("[SKIP] categories_detail 未提供（非 T5 必需项）")

    print("[INFO] 原始自测输出：%s" % raw.strip()[-300:])
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
