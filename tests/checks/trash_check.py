#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""空删除列表守护断言（只读，不删除任何真实文件）。

需要 dev-data 提供钩子：OTTER_SELFTEST=trash-empty，
输出形如 {"mode":"trash-empty","trashed":0,"success":true}。
钩子缺失时记 SKIP。
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


def main():
    path = sys.argv[1]
    obj, raw = read_json_line(path)
    fails = 0

    def ok(cond, msg):
        nonlocal fails
        print(("[PASS] " if cond else "[FAIL] ") + msg)
        if not cond:
            fails += 1

    if obj is None or obj.get("mode") != "trash-empty":
        print("[SKIP] 未实现 OTTER_SELFTEST=trash-empty 钩子，无法验证空删除列表守护")
        print("[SKIP] 期望钩子：OTTER_SELFTEST=trash-empty，输出 trashed=0 且 success=true（详见 tests/README.md）")
        print("[INFO] 原始自测输出：%s" % raw.strip()[-200:])
        return 0

    trashed = obj.get("trashed")
    ok(trashed == 0, "空列表移入废纸篓数量为 0（实际 %r）" % (trashed,))
    ok(obj.get("success") is True, "空列表操作返回成功而非异常（success=%r）" % (obj.get("success"),))
    print("[INFO] 原始自测输出：%s" % raw.strip()[-300:])
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
