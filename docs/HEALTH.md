# 一键系统体检 / 空间账本

## 体检（只读）
侧栏第一项「体检」，启动时自动跑一次（也可手动重新体检）。

扫描项：
- 磁盘可用比例
- 可清理缓存/日志（NativeCleanService 预览，不含需管理员的系统缓存）
- 废纸篓 + Otter 回收站
- 主目录下 >500MB 的大文件（最多 20 个，跳过隐藏/包内）
- 用户 LaunchAgents 数量
- 电池健康度

输出：
- 0–100 健康分
- 按严重程度排序的问题卡片（磁盘不足 / 可清理 / 废纸篓 / 大文件 / 启动项 / 长期未清理 / 电池）
- 每项「去处理」跳转到对应分区

体检本身不删除、不修改任何文件。

## 空间账本
记录 clean / space / uninstall 操作：
- 累计释放、移入回收站
- 最近 3 条记录
- 可清空历史

存储：~/Library/Application Support/Otter/history.json

## 自测
OTTER_SELFTEST=history-fixture：写入/重载/汇总，断言 2 条记录。
OTTER_SELFTEST=health-score：磁盘+缓存问题打分 ≤65。
