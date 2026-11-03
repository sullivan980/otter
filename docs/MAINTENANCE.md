# 维护（只读诊断）

维护页只做系统状态读取，不执行 DNS / Spotlight / 字体缓存等有风险操作。

## 检测项
- 系统：macOS 版本、架构、机型、已运行时间
- 磁盘：卷名、SSD/HDD、SMART 状态、可用 / 总量
- 电池：健康度、循环次数、温度、供电状态（台式机显示未检测到）
- 传感器：GPU 使用率 / GPU 内存（IOAccelerator）、热压力（ProcessInfo.thermalState）；
  温度需要特权 SMC，当前显示「不可用」
- Spotlight：mdutil 索引状态
- 本地快照：tmutil 快照数量
- 启动项：用户/系统 LaunchAgents 与系统 LaunchDaemons 数量

## 维护任务（仅说明）
- 刷新 DNS 缓存（需管理员）
- 重建 Spotlight 索引（高风险、高耗时）
- 重建字体缓存（需重启）
- 运行系统定期维护脚本（需管理员）

## 受控执行
- **刷新 DNS 缓存**：已支持，点击「执行…」→ 二次确认 → 一次管理员授权；
  命令固定为 `dscacheutil -flushcache; killall -HUP mDNSResponder`，不拼接用户输入。
- Spotlight 重建、字体缓存、定期脚本：仍只做说明，不执行。

## 自测
OTTER_SELFTEST=maintenance：输出 OS/机型/Spotlight/快照/启动项/SMART/SSD/容量 JSON。
OTTER_SELFTEST=maintenance-action：断言 DNS 刷新命令为固定白名单内容（不执行）。