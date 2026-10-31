#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OTTER_SELFTEST=uninstall 输出断言（只读扫描）。

实际输出字段（dev-data）：mode / ok / apps / first_app{name,bundleId,leftovers,totalBytes,kinds}。
判定：ok=true、应用数>0、首个应用残留结构合法。
"""
import json
import os
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


def count_installed_apps():
    roots = ["/Applications", os.path.expanduser("~/Applications")]
    count = 0
    for root in roots:
        if not os.path.isdir(root):
            continue
        try:
            for name in os.listdir(root):
                if name.endswith(".app"):
                    count += 1
        except OSError:
            continue
    return count


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
        print("[FAIL] uninstall 自测输出不是合法 JSON；原始输出末尾：")
        print(raw[-400:])
        return 1

    ok(obj.get("mode") == "uninstall", 'mode 必须为 "uninstall"（实际：%r）' % (obj.get("mode"),))
    if "ok" in obj:
        ok(obj.get("ok") is True, "扫描成功 ok=true（error：%r）" % (obj.get("error"),))

    apps_key, apps = pick(obj, ["apps", "app_count", "count"])
    if apps_key is None:
        print("[FAIL] 缺少应用数字段（apps/app_count/count）")
        if obj.get("error"):
            print("[FAIL] 自测错误：%s" % obj.get("error"))
        print("[INFO] 原始自测输出：%s" % raw.strip()[-300:])
        fails += 1
    else:
        ok(is_num(apps) and apps > 0, "应用数 > 0（字段 %s，实际 %r）" % (apps_key, apps))
        try:
            installed = count_installed_apps()
            if is_num(apps) and installed > 0:
                ok(apps <= installed + 5,
                   "应用数与 /Applications + ~/Applications 的实际数量不矛盾（扫描 %r，系统 %d）"
                   % (apps, installed))
        except Exception as exc:
            print("[SKIP] 无法核对已安装应用数量：%s" % exc)

    first = obj.get("first_app")
    if not isinstance(first, dict):
        first = obj.get("first")
    if isinstance(first, dict):
        name = first.get("name")
        ok(isinstance(name, str) and bool(name), "首个应用名称非空（实际：%r）" % (name,))
        lk, lv = pick(first, ["leftovers", "leftover_count", "residuals"])
        if lk is None:
            ok(False, "首个应用的残留结构缺少 leftovers/leftover_count 字段")
        else:
            ok(is_num(lv) and lv >= 0, "首个应用残留数 >= 0（字段 %s，实际 %r）" % (lk, lv))
        tk, tv = pick(first, ["totalBytes", "total_bytes", "total_size"])
        if tk is not None:
            ok(is_num(tv) and tv >= 0, "首个应用残留总大小 >= 0（字段 %s，实际 %r）" % (tk, tv))
        kinds = first.get("kinds")
        if isinstance(kinds, dict):
            ok(all(is_num(v) and v >= 0 for v in kinds.values()),
               "残留分类计数结构合法（kinds=%r）" % (kinds,))
            if is_num(lv):
                ok(sum(v for v in kinds.values() if is_num(v)) == lv,
                   "kinds 计数之和等于 leftovers（%r vs %r）" % (kinds, lv))
        elif lk is not None:
            print("[SKIP] first_app.kinds 未提供（残留分类结构非必需）")
    elif obj.get("first_leftovers") is not None:
        fl = obj.get("first_leftovers")
        ok(is_num(fl) and fl >= 0, "首个应用残留数 >= 0（first_leftovers，实际 %r）" % (fl,))
    else:
        ok(False, "缺少残留结构字段（first_app/first），无法验证残留扫描")

    print("[INFO] 原始自测输出：%s" % raw.strip()[-300:])
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
