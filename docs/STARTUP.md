# 启动项管理

侧栏 → 启动项。

## 展示
- 用户 LaunchAgents：~/Library/LaunchAgents
- 系统 LaunchAgents：/Library/LaunchAgents
- 系统 LaunchDaemons：/Library/LaunchDaemons

每项显示：Label、程序路径、RunAtLoad / KeepAlive、是否 Disabled、plist 修改时间；
「在 Finder 中显示」定位 plist。

## 禁用 / 启用
- **用户项**：可直接操作；写入 plist 的 Disabled，并同步 launchctl bootout/bootstrap。
- **系统项**：需要管理员权限，当前版本只读（显示「需管理员」）。
- 不支持登录项（SMAppService）与后台项（BTM），后续可补。

## 自测
OTTER_SELFTEST=startup-fixture：临时目录 3 个 plist，断言扫描 3 项、用户项可禁用、
系统项被拒绝。
