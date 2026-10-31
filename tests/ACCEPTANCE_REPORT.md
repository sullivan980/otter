# Otter 原生版 · 最终验收报告（T5）

| 项 | 值 |
|---|---|
| 日期 | 2026-10-31 16:24（Asia/Shanghai） |
| 被测产物 | /Users/ksullivan/Code/deepseek/otter2/build/Otter.app |
| 二进制 SHA-256 | 0feed95bfc3f13003c401a39aad36224e9c5fdd19894e939e556304b2662a6ed（4,033,376 B，16:14 构建） |
| 版本 | 0.2.0 / build 1，arm64-apple-macos13.0，LSUIElement=true |
| 验收命令 | ./scripts/verify.sh --no-build（快速采样；此前 --full 正式采样已跑） |
| 最终退出码 | 0（全部检查项通过） |
| 证据目录 | /tmp/otter2-evidence/verify/、/tmp/t5-verify-final.log、/tmp/t5-verify-full2.log、/tmp/t5-tests.log、/tmp/t5-boot-*.json |

## 1. 汇总

| 类别 | 结果 |
|---|---|
| 最终 verify 检查项 | 通过 24 / 失败 0 / 跳过 3（SKIP 均因沙箱或 AX 权限，已列明替代证据） |
| 功能自测 tests/run_all.sh | 7 个脚本 / 56 条断言全部通过（metrics 15、clean 7、uninstall 9、parse 5、menubar 8、manifest 5、错误路径 7） |
| 构建 | 0 error（并发期曾因团队多人构建出现 SIGTERM/源文件并发修改，最终稳定产物重跑通过） |
| 主界面四分区 | 4/4 通过：clean / uninstall / disk / settings 均 960x660（flags 文件启动） |
| 红线 | 未执行真实清理/优化/删除；clean 仅 dry-run；卸载只测只读扫描与空删除守护 |

## 2. 功能项逐条（按 ACCEPTANCE）

| 项 | 结论 | 证据 / 说明 |
|---|---|---|
| MB-06/07/12 菜单栏格式（不补零/单位/空态） | PASS | OTTER_SELFTEST=menubar：dual=42% 61%、zero=0% 0%、full=100% 100%、net=↑1.5G/s ↓820K/s、empty=Otter、reordered 顺序相反 |
| MB-01/09/10/14/15 菜单栏外观/阈值色/模板图标/点击/右键 | BLOCKED（人工） | AX 权限 -10004；证据：Lead 手工截图 /tmp/o2-shots/* |
| HD-01 HUD 固定 400x520 | PASS | winlist：id=3557，尺寸 400x520 |
| HD-02/05/06/08 区块/按钮路由/空态/关闭 | 部分自动化（窗口）+ 人工截图 | HUD 手工截图 /tmp/o2-shots |
| HD-16 / NF-02 HUD footprint | PASS | 最大 19.2MB（≤32MB） |
| CL-02 清理 dry-run | PASS | 直启 + 沙箱安全 HOME：categories=14、items=16、totalBytes≈1.485GB、potential≈1.19GB；未真实清理 |
| CL-06/07/08/09 勾选/全选/二次确认/空计划 | 人工/UI | 代码走查 + dev-ui 手工截图 |
| UN-01/04 应用列表+残留扫描 | PASS | apps=17；首个 Apifox residue=3（kinds: app/data/prefs，totalBytes≈787MB） |
| UN-07/09/10/14 确认/不存在/空残留/真实 trash | 只读守护 PASS，真实删除未测 | trash-empty：trashed=0、success=true；真实删除按红线未执行 |
| DK-01/02 磁盘分区 | PASS（窗口） | 960x660 窗口存在；分析内页人工 |
| ST-01..ST-16 设置 | PASS（窗口）/人工项 | 设置窗口 960x660；持久化、插件安装删除等人工 |
| PL-01/04/05/13 插件加载与错误路径 | PASS | 内置 n1/n8 manifest 合法且随包；坏 JSON→rejected、空目录/不存在目录不崩溃；用户插件 UI 安装人工 |
| OB-01..OB-07 首启引导 | BLOCKED（未自动测） | 需清偏好 + 人工点击；建议发布前手工走查 |
| NT-01..NT-04 通知 | BLOCKED | ad-hoc 未安装到 /Applications 时 UNUserNotificationCenter 拒绝授权（日志：Notifications are not allowed for this application）；需安装后人工验证 |
| LC-01/02/03 生命周期 | 启动 PASS；关闭/退出人工 | 启动后菜单栏+HUD 正常、进程存活 |
| SR/CP | PASS | clean 参数仅 --dry-run；构建 target/plist 均 macOS 13.0；源码无 URLSession |

## 3. 非功能实测（NF）

| 编号 | 指标 | 实测 | 判定 |
|---|---|---|---|
| NF-01 | 空载 footprint（≤25MB） | 最大 18.3MB（快速 3 次×2s）；--full 正式 5 次×12s 最大 18.5MB | PASS |
| NF-02 | HUD footprint（≤32MB） | 最大 19.2MB（--full 19.0MB） | PASS |
| NF-03 | 主界面 footprint（≤90MB） | 最大 32.8MB（--full 26.8MB） | PASS |
| NF-04/05 | CPU 空载 ≤0.5% / HUD ≤2% | 无法测：DSH 沙箱禁止 ps/top 读取进程 CPU | BLOCKED（需独立测试机） |
| NF-06 | 启动到菜单栏 ≤400ms | 3 次中位数 193ms（194/193/172） | PASS |
| NF-07 | .app 包体（修订后 ≤16MB） | 14.6MB | PASS |
| NF-10 | 无网络 | lsof -a -p PID -i 为空；源码无 URLSession/NSURLConnection | PASS |
| NF-11 | 无 Dock 图标 | Info.plist LSUIElement=true；lsappinfo 直启未注册，以 plist 兜底 | PASS（部分 SKIP） |
| NF-09/12/13/14/15 | 深浅色 / 24h / 泄漏循环 / VoiceOver / 唤醒 | 未测（人工/长跑） | 未覆盖 |

## 4. 已知限制与风险

1. 启动方式差异：本机 open --args -OTTER_X=Y 不生效；GUI 验收改用 /tmp/otter-test-flags.json（showMain/mainSection/noOnboard/autoScan/showHUD）。HUD 与空载内存用直启二进制（不影响 AppKit 启动作时序）；clean 用「直启 + 假 HOME + 只读符号链接」保证 mole 写入只落 /tmp。真实用户由 LaunchServices 启动时 mole/通知不受此限制。
2. 通知：ad-hoc 未安装到 /Applications 时授权被拒，NT 项需安装后人工验证。
3. CPU：沙箱无法读取进程 CPU，NF-04/05 需独立测试机跑 5 分钟均值。
4. 首启引导/深浅色/多显示器/24h 稳定性/VoiceOver：本轮未自动化，发布前人工走查。
5. 并发构建：团队并行构建会导致 swiftc 被 SIGTERM 或 modified during build，verify 已内置 3 次并发重试与 600s 脚本级保护；最终验收在稳定产物上重跑通过。
6. 旧项目只读：otter/ 的 git 工作区存在既有改动（M src-tauri/src/main.rs、?? REQUIREMENTS.md、?? PRODUCT_REVIEW.md），为本次任务前已存在；T5 全程未写 otter/。
7. screenshot.sh：脚本已支持 HUD/四分区/菜单栏批量截图，但本机 LaunchServices --args 不传参；需改用 flags 文件方式（待最后一步小修）。本轮界面证据采用 Lead 手工截图：/tmp/o2-shots/clean-done2.png、sec-uninstall.png、sec-disk.png、sec-settings.png。

## 5. 复跑命令

    cd /Users/ksullivan/Code/deepseek/otter2
    pkill -f 'Otter.app/Contents/MacOS/Otter' 2>/dev/null || true
    ./scripts/verify.sh --full        # 构建 + 56 断言 + NF 正式采样 + 四分区
    ./tests/run_all.sh                # 只跑功能自测
    ./scripts/screenshot.sh           # 截图存证（flags 方式修复后）

## 6. 结论

可交付（自动化门禁全绿）。P0 自动化项全部 PASS；SKIP/BLOCKED 项均为环境权限或需人工/安装后验证，已在第 4 节逐条列明并给出替代证据，无 S1/S2 缺陷。建议 Lead 收尾前补三项人工确认：菜单栏外观/深浅色、通知（安装到 /Applications 后）、首启引导。
