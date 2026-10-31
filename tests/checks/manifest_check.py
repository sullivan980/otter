#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""内置插件 manifest 静态校验（只读）。

用法：manifest_check.py <插件目录>
契约（T4 实现）：id / name / version 必填；rows[metric,style]（label 可选）；
width/height 若声明必须为 HUD 固定尺寸 400x520；colors 可选。
"""
import json
import os
import sys

KNOWN_METRICS = {"cpu", "mem", "disk", "up", "down", "procs"}


def main():
    root = sys.argv[1]
    files = sorted(name for name in os.listdir(root) if name.endswith(".json"))
    fails = 0
    if not files:
        print("[FAIL] 插件目录为空：%s" % root)
        return 1
    for name in files:
        path = os.path.join(root, name)
        try:
            with open(path, "r", encoding="utf-8") as fh:
                obj = json.load(fh)
        except (OSError, json.JSONDecodeError) as exc:
            print("[FAIL] %s 不是合法 JSON：%s" % (name, exc))
            fails += 1
            continue
        errors = []
        if not isinstance(obj.get("id"), str) or not obj.get("id"):
            errors.append("缺少非空 id")
        if not isinstance(obj.get("name"), str) or not obj.get("name"):
            errors.append("缺少非空 name")
        if "version" not in obj:
            errors.append("缺少 version")
        rows = obj.get("rows")
        if not isinstance(rows, list) or not rows:
            errors.append("rows 必须是非空数组")
            rows = []
        else:
            for idx, row in enumerate(rows):
                if not isinstance(row, dict):
                    errors.append("rows[%d] 不是对象" % idx)
                    continue
                metric = row.get("metric")
                style = row.get("style")
                if not isinstance(metric, str) or not metric:
                    errors.append("rows[%d] 缺少 metric" % idx)
                elif metric not in KNOWN_METRICS:
                    errors.append("rows[%d].metric 未知：%s" % (idx, metric))
                if not isinstance(style, str) or not style:
                    errors.append("rows[%d] 缺少 style" % idx)
                if row.get("label") is not None and not isinstance(row.get("label"), str):
                    errors.append("rows[%d].label 必须是字符串或 null" % idx)
        width = obj.get("width")
        height = obj.get("height")
        if width is not None or height is not None:
            if width != 400 or height != 520:
                errors.append("HUD 尺寸必须固定 400x520（实际 %rx%r）" % (width, height))
        if "radius" in obj and not isinstance(obj.get("radius"), (int, float)):
            errors.append("radius 必须是数字")
        if "colors" in obj and not isinstance(obj.get("colors"), (dict, list)):
            errors.append("colors 必须是对象或数组")
        if errors:
            print("[FAIL] %s：%s" % (name, "；".join(errors)))
            fails += 1
        else:
            print("[PASS] %s：id=%s name=%s rows=%d%s"
                  % (name, obj.get("id"), obj.get("name"), len(rows),
                     "（400x520）" if width is not None else ""))
        stem = os.path.splitext(name)[0]
        if isinstance(obj.get("id"), str) and obj.get("id") != stem:
            print("[INFO] %s：id(%s) 与文件名(%s) 不同（允许，但需确认引用关系）" % (name, obj.get("id"), stem))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
