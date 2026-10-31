#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OTTER_SELFTEST=metrics 输出断言（只读）。

判定：ok=true；CPU 0-100、内存总量>0、磁盘>0、上传/下载>=0；
并交叉校验 sysctl hw.memsize / hw.ncpu 与 statvfs("/")，防止占位数据蒙混。
"""
import json
import os
import subprocess
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


def main():
    path = sys.argv[1]
    obj, raw = read_json_line(path)
    fails = 0

    def ok(cond, msg):
        nonlocal fails
        print(("[PASS] " if cond else "[FAIL] ") + msg)
        if not cond:
            fails += 1

    def skip(msg):
        print("[SKIP] " + msg)

    if obj is None:
        print("[FAIL] metrics 自测输出不是合法 JSON；原始输出末尾：")
        print(raw[-400:])
        return 1

    ok(obj.get("mode") == "metrics", 'mode 必须为 "metrics"（实际：%r）' % (obj.get("mode"),))
    if "ok" in obj:
        ok(obj.get("ok") is True, "采样器自报 ok=true（实际：%r）" % (obj.get("ok"),))
    else:
        skip("缺少 ok 字段（旧版自测格式）")

    cpu = obj.get("cpu")
    ok(is_num(cpu) and 0 <= cpu <= 100, "CPU 在 0-100（实际：%r）" % (cpu,))
    mem_pct = obj.get("mem_used_pct")
    if mem_pct is None:
        skip("mem_used_pct 字段缺失（非 T5 必需项，跳过）")
    else:
        ok(is_num(mem_pct) and 0 <= mem_pct <= 100, "内存使用率在 0-100（实际：%r）" % (mem_pct,))

    mem_total = obj.get("mem_total")
    ok(is_num(mem_total) and mem_total > 0, "内存总量 > 0（实际：%r）" % (mem_total,))
    disk_total = obj.get("disk_total")
    ok(is_num(disk_total) and disk_total > 0, "磁盘总量 > 0（实际：%r）" % (disk_total,))
    down = obj.get("down")
    ok(is_num(down) and down >= 0, "下载速率 >= 0（实际：%r）" % (down,))
    up = obj.get("up")
    ok(is_num(up) and up >= 0, "上传速率 >= 0（实际：%r）" % (up,))

    try:
        hw_mem = int(subprocess.check_output(["sysctl", "-n", "hw.memsize"]).strip())
        if is_num(mem_total):
            tolerance = max(1.0, hw_mem * 0.001)
            ok(abs(mem_total - hw_mem) <= tolerance,
               "内存总量与系统 hw.memsize 一致（自测 %r vs 系统 %d）" % (mem_total, hw_mem))
        else:
            skip("内存总量非数值，跳过 hw.memsize 交叉校验")
        machine_mem = obj.get("machine_mem_total")
        if is_num(machine_mem):
            ok(machine_mem == hw_mem, "machine_mem_total 与 hw.memsize 一致（%r vs %d）" % (machine_mem, hw_mem))
    except Exception as exc:
        skip("无法读取 hw.memsize 交叉校验：%s" % exc)

    try:
        st = os.statvfs("/")
        disk_sys = st.f_blocks * st.f_frsize
        if is_num(disk_total) and disk_sys > 0:
            diff = abs(disk_total - disk_sys) / disk_sys
            ok(diff <= 0.005,
               '磁盘总量与 statvfs("/") 一致（自测 %r vs 系统 %d，偏差 %.2f%%）'
               % (disk_total, disk_sys, diff * 100))
        else:
            skip("磁盘总量非数值，跳过 statvfs 交叉校验")
    except Exception as exc:
        skip("无法执行 statvfs 交叉校验：%s" % exc)

    cores = obj.get("cores")
    if cores is None:
        skip("cores 字段缺失（非 T5 必需项，跳过）")
    else:
        try:
            ncpu = int(subprocess.check_output(["sysctl", "-n", "hw.ncpu"]).strip())
            ok(is_num(cores) and int(cores) == ncpu, "核数与 hw.ncpu 一致（自测 %r vs 系统 %d）" % (cores, ncpu))
        except Exception as exc:
            skip("无法读取 hw.ncpu 交叉校验：%s" % exc)

    top = obj.get("top", obj.get("top_processes"))
    if isinstance(top, list):
        ok(len(top) <= 10, "TOP 进程数量合理（%d 项）" % len(top))
        if top:
            entry = top[0]
            ok(isinstance(entry, dict) and isinstance(entry.get("name"), str) and entry.get("name"),
               "TOP 进程条目含非空 name（首项：%r）" % (entry,))
            ok(isinstance(entry, dict) and is_num(entry.get("cpu")),
               "TOP 进程条目含数值 cpu（首项：%r）" % (entry,))
    elif is_num(top):
        ok(0 <= top <= 30, "TOP 进程数量合法（实际 %r）" % (top,))
    else:
        skip("top 字段缺失或格式未知（非 T5 必需项，跳过）")

    print("[INFO] 原始自测输出：%s" % raw.strip()[-300:])
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
