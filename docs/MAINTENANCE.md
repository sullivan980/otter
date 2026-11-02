# 维护（只读诊断）

维护页只做系统状态读取，不执行 DNS / Spotlight / 字体缓存等有风险操作。

## 检测项
- 系统：macOS 版本、架构、机型、已运行时间
- 磁盘：卷名、SSD/HDD、SMART 状态、可用 / 总量
- Spotlight：mdutil 索引状态
- 本地快照：tmutil 快照数量
- 启动项：用户/系统 LaunchAgents 与系统 LaunchDaemons 数量

## 维护任务（仅说明）
- 刷新 DNS 缓存（需管理员）
- 重建 Spotlight 索引（高风险、高耗时）
- 重建字体缓存（需重启）
- 运行系统定期维护脚本（需管理员）

当前版本不执行这些动作，只展示影响说明，后续如需执行会单独加受控入口。

## 自测
OTTER_SELFTEST=maintenance：输出 OS/机型/Spotlight/快照/启动项/SMART/SSD/容量 JSON。
