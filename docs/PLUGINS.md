# Otter 插件与主题（热加载，不用重装应用）

## 目录

- HUD 插件：~/Library/Application Support/Otter/plugins/*.json
- 主题：~/Library/Application Support/Otter/themes/*.json

两个目录会在应用启动时创建；文件保存后 0.5 秒自动重载（不需要重启，更不需要重装）。
设置页里也有「打开目录 / 重新加载」按钮。

## HUD 插件 manifest（v2）

    {
      "id": "n10",
      "name": "N10 极简列表",
      "version": "1.0.0",
      "author": "you",
      "width": 400,
      "height": 520,
      "radius": 16,
      "style": { "cardRadius": 10, "spacing": 5, "showSparkline": false, "background": "theme" },
      "rows": [
        { "metric": "cpu",  "style": "big",  "label": null },
        { "metric": "mem",  "style": "bar",  "label": null },
        { "metric": "disk", "style": "bar",  "label": null },
        { "metric": "up",   "style": "text", "label": null },
        { "metric": "down", "style": "text", "label": null },
        { "metric": "procs","style": "text", "label": "TOP 进程" }
      ]
    }

- rows 支持 metric：cpu / mem / disk / up / down / procs / clock / uptime / divider；
  style：big / bar / ring / text / divider。
- style（v2 新增，均可选）：cardRadius 卡片圆角、spacing 卡片间距、
  showSparkline 是否显示火花线、background（material / solid / theme）。
- 用户插件 id 不能与内置插件相同（内置 n1 / n8），请用新 id，例如 n10。

## 主题 JSON

    {
      "id": "X1",
      "name": "海盐",
      "tagline": "冷灰蓝 · 自定义主题",
      "dark": true,
      "accent": "#7FD8E8",
      "backgroundTop": "#12303B",
      "backgroundBottom": "#08171E",
      "sidebar": "#0E2730",
      "panel": "#FFFFFF1A",
      "panelStroke": "#FFFFFF26",
      "radius": 16,
      "material": true
    }

- 颜色支持 #RRGGBB 与 #RRGGBBAA（后两位是 alpha）。
- 用户主题 id 与内置相同会覆盖内置（A–E），方便直接迭代内置样式而不重装；
  想保留内置就把 id 换成新的，比如 X1。
- 改完主题文件后如果当前正选中它，会自动重新应用。

## 内置 vs 用户

| 类型 | 位置 | 能否删除 |
|---|---|---|
| 内置 HUD 插件 n1 / n8 | App 包内 Resources/plugins | 不能 |
| 用户 HUD 插件 | 用户目录 plugins/ | 能（设置页删除） |
| 内置主题 A–E | 代码内置 | 不能（但可被同 id 用户主题覆盖） |
| 用户主题 | 用户目录 themes/ | 能（删文件 + 重新加载） |

## 为什么不重装就能改样式

- HUD 的布局、间距、圆角、火花线开关全部来自 manifest，HUD 监听插件变更后立即重建；
- 主题色板来自 JSON，ThemeStore 重新加载时通知所有视图刷新；
- 文件监听器（PluginWatcher）监听两个目录，保存 JSON 即触发重载。

后续如果选定了 HUD 样式，我会把它落成一个 manifest（内置或用户插件），
再调间距/圆角/密度只需要改 JSON 或替换一张内置 manifest，应用不用重新安装。
