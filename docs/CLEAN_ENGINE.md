# 清理引擎（原生 / mole）

设置 → 通用 → 清理引擎可切换，默认原生。

## 原生引擎（native）
只处理用户级安全目录，按勾选执行：

| 分类 | 路径 |
|---|---|
| 用户缓存 | ~/Library/Caches/* |
| 用户日志 | ~/Library/Logs/* |
| 废纸篓 | ~/.Trash/* |
| Xcode 缓存 | ~/Library/Developer/Xcode/DerivedData、CoreSimulator/Caches |
| 开发缓存 | ~/.npm/_cacache、~/.gradle/caches |

- 白名单路径自动跳过；删除确认后不可恢复。
- 暂不包含需要 root 的系统缓存（/Library/Caches 等），这部分仍可用 mole。

## mole 引擎
调用内置 mole，包含系统级缓存；但 CLI 不支持按分类执行，勾选只用于统计与确认。

## 自测
- OTTER_SELFTEST=clean-native-fixture：/tmp 下创建两项，预览→全选→删除，
  断言 freedBytes ≥ 2,000,000 且目录消失。
