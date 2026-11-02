# 清理引擎（原生，0.8 起）

0.8 起 mole 已从应用内移除，清理 / 卸载 / 空间扫描全部为原生 Swift 实现。

## 清理分类

| 分类 | 路径 |
|---|---|
| 用户缓存 | ~/Library/Caches/* |
| 用户日志 | ~/Library/Logs/* |
| 废纸篓 | ~/.Trash/* |
| Xcode 缓存 | ~/Library/Developer/Xcode/DerivedData、CoreSimulator/Caches |
| 开发缓存 | ~/.npm/_cacache、~/.gradle/caches |
| 系统缓存（需授权） | /Library/Caches/*（默认不勾选；只允许该前缀，脚本单引号转义） |

- 只列实际占用 >0 的项；白名单路径跳过。
- 按勾选条目执行；确认后直接删除，不可恢复。
- 系统缓存需要一次管理员授权（osascript），默认不勾选；`PrivilegedCleaner` 只接受 `/Library/Caches/` 下的路径，拒绝 `..`、符号链接与白名单路径。

## 卸载
- 应用列表来自 /Applications、~/Applications。
- 残留：应用本体、Caches、Preferences、Application Support、Logs、
  Saved Application State、WebKit、HTTPStorages、Containers、Group Containers、
  Application Scripts、LaunchAgents。
- 移入废纸篓，可还原。

## 空间
见 docs/SPACE.md。

## 自测
- OTTER_SELFTEST=clean：原生清理只读预览（分类/条目/字节）。
- OTTER_SELFTEST=clean-native-fixture：/tmp 预览→全选→删除，断言 bytes 与目录消失。
- OTTER_SELFTEST=priv-guard：断言提权路径只保留 /Library/Caches 子项，/etc 与 .. 被拒绝。
- OTTER_SELFTEST=uninstall-fixture：/tmp 假应用 + 残留，断言应用/残留/启动项被识别。
## Otter 回收站（安全清理）

- 清理（用户级）不再直接删除，而是移动到
  ~/Library/Application Support/Otter/trash/<批次>/，并写 manifest.json。
- 设置 → Otter 回收站：恢复全部 / 清空回收站（清空才真正释放磁盘）。
- 系统缓存需要管理员，不进入回收站，仍为确认后直接删除。
