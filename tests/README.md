# Otter 原生版 · 测试与验收基建（T5）

本目录与 `scripts/verify.sh`、`scripts/screenshot.sh` 构成独立的只读验收体系：
不修改 Sources/，不执行任何真实清理 / 优化 / 删除应用。验收在开发期间可反复复跑。

## 快速开始

```bash
cd /Users/ksullivan/Code/deepseek/otter2
./scripts/verify.sh          # 构建 → 功能自测 → 启动/HUD/内存/无网络 → 主界面四分区 → 退出
./scripts/screenshot.sh      # HUD + 四分区 + 菜单栏截图到 /tmp/otter2-shots/
```

## scripts/verify.sh

阶段与判定：

1. **环境检查**：/tmp/winlist、/tmp/footprint、python3 是否可用。
2. **构建**：scripts/build.sh 退出码 0 且日志无 `error:`；并发编辑导致
   “was modified during the build” 时自动重试（最多 3 次）；脚本级保护默认 600s（OTTER_BUILD_TIMEOUT）。
3. **产物结构**：LSUIElement=true、内置 mole 可执行、包体积 ≤ 上限、内置插件随包且内容一致。
4. **功能自测**：tests/run_all.sh（全部只读）。
5. **启动/HUD**：空载与 HUD 用直启二进制（结果确定、可捕获日志）；主界面用
   `open -n build/Otter.app --args -OTTER_*`（LaunchServices，脱离 DSH 沙箱），
   检查进程存活、400×520 窗口、footprint、运行期无网络连接。
6. **主界面四分区**：OTTER_MAIN_SECTION=clean/uninstall/disk/settings 逐个启动，窗口存在且尺寸 ≥760×520。
7. **收尾**：pkill 测试进程，输出证据目录。

退出码：

| 码 | 含义 |
|---|---|
| 0 | 全部通过 |
| 1 | 有验收项失败（构建成功） |
| 2 | 构建失败（后续检查未执行） |
| 3 | 环境/基建错误（缺 winlist/footprint/python3 或参数错误） |

可调环境变量：

| 变量 | 默认 | 说明 |
|---|---|---|
| OTTER_FOOTPRINT_IDLE_MB | 25 | 空载上限（NF-01，P0） |
| OTTER_FOOTPRINT_HUD_MB | 32 | HUD 打开态上限（NF-02，P1） |
| OTTER_FOOTPRINT_MAIN_MB | 90 | 主界面上限（NF-03，P1） |
| OTTER_BUNDLE_MAX_MB | 16 | .app 包体积上限（NF-07，已按内嵌 mole 硬成本调整） |
| OTTER_VERIFY_WARMUP / SAMPLES / INTERVAL | 5/3/2 | 采样参数；`--full` 为 30/5/12 |
| OTTER_BUILD_TIMEOUT | 600 | 构建脚本级保护（秒） |
| OTTER_VERIFY_TESTS_TIMEOUT | 900 | 功能自测总超时（秒） |

参数：`--no-build`（增量复测）、`--no-tests`（快速窗口/内存复测）、`--keep`
（保留最后进程）、`--full`（按 ACCEPTANCE 正式采样：预热 30s、5 次×12s，不替代发布门禁）。

证据目录：`/tmp/otter2-evidence/verify/`（build.log、tests.log、idle.log、hud.log、main-*.log、boot-*.log）。

## scripts/screenshot.sh

默认截 /tmp/otter2-shots/：hud.png、main-clean.png、main-uninstall.png、
main-disk.png、main-settings.png、menu-bar.png（顶部 80px 全宽裁剪）。

参数：`--out DIR`、`--only hud|clean|uninstall|disk|settings|all`、`--keep`、`--full`。
截图需要系统「屏幕录制」权限；失败时退出码 1 并逐项说明。

## tests/

| 脚本 | 覆盖 | 红线 |
|---|---|---|
| test_selftest_metrics.sh | CPU 0-100、内存总量>0、磁盘>0、网络≥0；与 sysctl/statvfs 交叉校验防占位数据 | 只读 |
| test_selftest_clean.sh | 直启 + 沙箱安全 HOME 跑 OTTER_SELFTEST=clean（mole 写入只落 /tmp），断言分类数>0、总大小≥0 | 只 dry-run |
| test_selftest_uninstall.sh | 应用数>0、首个应用残留结构合法、应用数与系统实际数量不矛盾 | 只读扫描 |
| test_mole_parse.sh | 用旧版真实 dry-run 样本（fixtures/clean_dry_run.txt）断言分类/汇总解析 | 只读样本 |
| test_menubar.sh | 不补零（无 04%）、0%/100% 边界、速率带单位、空态回退 Otter、reordered 生效 | 只读 |
| test_plugin_manifests.sh | Resources/plugins/*.json 结构合法（id/name/version/rows，HUD 400x520）；.app 内是否随包且内容一致 | 只读 |
| test_error_paths.sh | 非法插件 manifest 被拒、空插件目录、不存在目录不崩溃、空删除列表守护 | 只用临时目录/拒绝路径 |

单独运行：`./tests/test_selftest_metrics.sh`；全部：`./tests/run_all.sh`。

## OTTER_SELFTEST 输出契约（数据层/壳层实现，T5 只消费）

| 模式 | 期望输出（一行 JSON） |
|---|---|
| metrics | `{"mode":"metrics","cpu":N,"mem_used_pct":N,"mem_total":N,"disk_total":N,"down":N,"up":N,"cores":N,"top":N}` |
| clean | `{"mode":"clean","ok":true,"categories":N,"items":N,"totalBytes":N,"categories_detail":[...]}`（仅 dry-run） |
| uninstall | `{"mode":"uninstall","ok":true,"apps":N,"first_app":{"name":"X","leftovers":N,"totalBytes":N,"kinds":{...}}}` |
| parse | `{"mode":"parse","categories":4,"summary_categories":6,"summary_items":265,"potential_bytes":N}`（读 OTTER_SELFTEST_INPUT） |
| menubar | `{"dual":...,"zero":...,"full":...,"net":...,"reordered":...,"empty":...}` |
| plugins | `{"mode":"plugins","valid":[...],"rejected":["{\"file\":\"bad.json\",\"error\":\"...\"}"]}`（rejected 为 JSON 字符串；读 OTTER_PLUGIN_DIR） |
| trash-empty | `{"mode":"trash-empty","trashed":0,"success":true}` |

钩子缺失时对应断言记 `[SKIP]`，并在验收报告中如实标注“未实现（缺钩子）”，不伪装通过。

跨沙箱说明：主界面验收用 `open -n <app> --args -OTTER_X=Y`（LaunchServices 脱离 DSH 沙箱；
Sources/Otter/App/main.swift 把 `-OTTER_*` 参数转为环境变量）。空载/HUD 与 clean 自测改用直启：
当前环境若存在同 bundle 的其它测试实例，open 会被 reopen 事件污染（自动开主窗口），
clean 则用「假 HOME + 只读符号链接」保证 mole 写入只落 /tmp。

## 红线与安全

- 不执行真实清理 / 优化 / 删除；clean 仅 `--dry-run`（由 OTTER_SELFTEST=clean 保证）。
- 卸载只测只读扫描与“空列表 / 拒绝路径”，不调用 trash 处理真实文件。
- 错误路径只用 `/tmp/otter2-t5/` 下临时目录。
- 测试会启动/退出 Otter、可能触发登录项注册（应用默认行为），但不改 UserDefaults、不写用户目录。

## 已知限制

- 菜单栏条目存在性无法用 AX 自动断言（System Events 权限 -10004）；改用
  OTTER_SELFTEST=menubar 断言文本格式 + screenshot.sh 人工看外观。
- GUI 验收统一用 `open` 启动，因此应用 stdout/stderr 不回传到日志；窗口/内存证据以 winlist/footprint 为准。
- 主界面实现尺寸 960x660（已由 Lead 确认规格，不再按 920x640 判定）。
- 启动到菜单栏 ≤400ms（NF-06）：verify.sh 尝试 OTTER_BOOT_LOG=1 + `ready Nms` 打点；未实现时记 SKIP（需 dev-shell 补打点）。
- CPU（NF-04/05）：DSH 沙箱禁止 ps/top 读取进程 CPU，verify.sh 记 SKIP，需人工/独立测试机测 5 分钟均值。
- footprint 用 /tmp/footprint（phys_footprint），不是 RSS；REQUIREMENTS 的 50MB 指 RSS，
  验收同时给出用户目标 25MB 与 REQUIREMENTS 上限，超上限才 FAIL。