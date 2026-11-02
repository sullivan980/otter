# Otter 水獭 · 原生版（otter2）

菜单栏常驻的 macOS 小工具：实时 CPU / 内存 / 磁盘 / 上传 / 下载，清理磁盘垃圾，干净卸载应用。
清理 / 卸载 / 空间扫描均为原生 Swift 实现，无第三方 CLI 依赖。

## 为什么重做

旧版 Tauri + WKWebView（`otter/`，冻结留档）：空载约 208MB RSS、菜单栏富文本不可读、缺自启/通知/引导/插件化。
原生版实测：**空载 footprint 18.9MB、HUD 打开 18.9MB、主界面扫描中约 36MB**（活动监视器口径），菜单栏默认 `42% 61%`（不补零、带单位、越界才变色）。

## 构建 / 运行

```bash
cd otter2
./scripts/build.sh          # swiftc → build/Otter.app（ad-hoc 签名，原子替换）
open build/Otter.app

./scripts/make_dmg.sh       # 组装 Otter-<版本>.dmg（Applications 软链）
./scripts/verify.sh         # 一键验收（构建/窗口/内存/测试/网络）
```

依赖：macOS 13+、命令行工具（swiftc / codesign / hdiutil）。无第三方依赖。
注意：当前 CommandLineTools 27.x 的 SDK 缺 SwiftUI 宏插件，build.sh 默认使用 `MacOSX26.5.sdk`（可用 `OTTER_SDK` 覆盖）。

## 功能

- **菜单栏**：自定义勾选（CPU/内存/磁盘/上传/下载）、固定宽度防抖动、5 种显示样式（数值/带名称/图标/中点/趋势）、獭图标可关；≥85% 才红。
- **HUD**（400×520，全屏 Space 可弹、不抢焦点）：纵向堆叠模块（CPU 曲线 + 8 核、内存曲线、磁盘容量、上下行、TOP3）+ 清理/卸载/主界面。
- **清理**：原生引擎扫描用户缓存/日志/废纸篓/Xcode/开发缓存 → 按勾选执行 → 系统通知；白名单保护。
- **卸载**：应用列表（搜索/排序）→ 关联残留扫描（本体/缓存/偏好/数据/日志/启动项/共享容器）→ 移入废纸篓。
- **磁盘**：只读目录分析（大目录/大文件，可下钻）。
- **空间**：安装包清理（dmg/pkg/xip…）+ 项目构建产物（node_modules/build/target…，7 天阈值）。
- **设置**：登录自启（SMAppService）、系统通知、菜单栏样式、菜单栏插件、HUD 插件、清理白名单、权限检测、欢迎引导重看。
- **插件 v1**：声明式 HUD manifest（`Resources/plugins/*.json` 内置；`~/Library/Application Support/Otter/plugins/<id>/manifest.json` 用户安装），设置页安装/启用/删除，非法 manifest 拒绝且回退内置。

## 架构

```
Sources/Otter/
├── App/          main / AppDelegate / AppState / Onboarding
├── Core/         Models / Formatters / Prefs / Services(协议) / Plugins / MenuBarFormat
├── Metrics/      RealMetricsSampler（host_processor_info / host_statistics64 / statfs / getifaddrs / libproc）
├── Engine/       NativeCleanService / UninstallService / SpaceService
├── Services/     Bootstrap / LoginItem / Notifications
└── UI/           StatusBarController / HUD* / MainWindowController / MainViews/
```

数据流：`AppState` 后台采样（HUD 可见 1s / 隐藏 2s）→ 主线程发布 → 菜单栏 + HUD 刷新。

## 验收与证据

- 规格：`docs/SPEC.md`；验收矩阵：`docs/ACCEPTANCE.md`；测试：`tests/` + `scripts/verify.sh`（证据默认落 `/tmp/otter2-evidence/`）。
- 开发/验收钩子：
  - 环境变量：`OTTER_SHOW_HUD=1`、`OTTER_SHOW_MAIN=1`、`OTTER_MAIN_SECTION=clean`、`OTTER_NO_ONBOARD=1`、`OTTER_AUTO_SCAN=clean|uninstall`、`OTTER_SELFTEST=metrics|clean|uninstall|parse|trash-empty|menubar|plugins|login-status`、`OTTER_LOGIN_OFF=1`。
  - 跨沙盒：`open -n build/Otter.app --args -OTTER_SHOW_MAIN=1`，或写 `/tmp/otter-test-flags.json`（键：showHUD/showMain/mainSection/autoScan/noOnboard/selftest/selftestOut）。

## 与旧版关系

- `otter/`：Tauri 版，冻结留档，仅作业务逻辑参考。
- `otter2/`：本仓库；需求见 `otter/REQUIREMENTS.md`。