# 空间清理（安装包 / 项目产物）

原生实现，不调用 mole。

## 安装包
- 扫描位置：~/Downloads、~/Library/Downloads、/Users/Shared/Downloads、
  iCloud Downloads、Mail Downloads、Telegram Desktop。
- 类型：.dmg / .pkg / .mpkg / .iso / .xip。
- 云端未下载的占位文件不列入（删除也释放不了空间）。
- 删除：二次确认后直接删除，不可恢复。

## 项目构建产物
- 扫描根目录：~/Code、~/Projects、~/Developer、~/Documents（深度 ≤7）。
- 产物名：node_modules、build、target、dist、.next、.nuxt、.output、DerivedData、
  .build、Pods、coverage、.turbo、.parcel-cache、out。
- build / dist / out 必须在 1–2 层内找到工程标记（package.json、build.gradle、
  Cargo.toml、*.xcodeproj、Package.swift 等），避免把 Maven 仓库当成产物。
- 只列 7 天以上未修改的目录；跳过隐藏目录（除非本身是产物名）。

## 白名单
- 设置 → 清理保护，可添加文件/目录；扫描与删除都会跳过。
- 存储：~/Library/Application Support/Otter/whitelist.json。

## 自测
- OTTER_SELFTEST=space-fixture：1MB 安装包 ×2 + node_modules/build/target，
  断言安装包 2 个、产物 2 个（build 被白名单保护）、删除 2 个、白名单目录仍在。
