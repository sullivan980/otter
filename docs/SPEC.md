# Otter 原生版产品规格（SPEC）

| 项 | 值 |
|---|---|
| 文档版本 | v1.0 |
| 日期 | 2026-10-31 |
| 作者 | 产品经理（T1） |
| 适用版本 | Otter 0.2.0（原生 Swift / AppKit + SwiftUI） |
| 代码基线 | otter2 骨架：Sources/Otter/{App,Core,Metrics,Mole,Services,UI} |
| 依据 | otter/REQUIREMENTS.md、otter/PRODUCT_REVIEW.md、现有骨架源码、otter/ui/hud-styles.js（N1/N8 定义） |
| 状态 | 待开发评审（未决项见第 11 章） |

> 规范用语：**必须** = 验收硬门槛；**应该** = P1，缺失需登记；**可以** = P2/后续。
> 本文只定义产品行为与验收口径，不规定具体 Swift 实现。所有界面文案以第 9 章为准，开发不得自创可见文案；新增文案须回填本文档。
> 接口以 Sources/Otter/Core/{Models,Services,Plugins,Prefs,Formatters}.swift 现有定义为准；第 10 章给映射，第 11 章列缺口。

---

## 0. 文档边界

**本版本（0.2.0）做**：菜单栏常驻 + 5 指标、HUD 400×520、主界面四分区（清理/卸载/磁盘/设置）、登录自启、系统通知、首启引导、插件 v1（声明式 HUD manifest）。

**本版本不做**：优化、历史、purge/installer、白名单管理、Touch ID、更新检查、多语言、菜单栏插件、插件 JS 沙箱、treemap（仅列 P2）。

**红线**：任何自动验收与开发自测只允许 mole dry-run 与守护路径测试；不执行真实清理、不真实删除应用；破坏性操作必须二次确认；删除一律进废纸篓。

---

## 1. 定位与用户旅程

### 1.1 一句话定位

**抬眼看得到 5 个实时指标，低头两下清干净磁盘。** 免费、开箱即用的 macOS 菜单栏「状态 + 清理」工具，内嵌 mole，不依赖 Homebrew，纯本地、不联网。

### 1.2 目标用户与 JTBD

| 用户 | 核心任务（JTBD） | 期望 |
|---|---|---|
| 普通 Mac 用户 | 不想装 iStat Menus / Mole for Mac，只想看一眼机器是否正常 | 菜单栏安静、可读、不费电 |
| 开发者 | 已用 mole，但不想记命令 | 图形化 dry-run → 勾选 → 清理 |
| 折腾型用户 | 想按自己的规则改造面板 | 插件目录 + 声明式 manifest，装完即生效 |

差异化：内嵌 mole（免装 CLI）+ 双窗口形态（菜单栏/HUD）+ 可插件化的状态面板。

### 1.3 设计原则（全文准绳）

1. **菜单栏安静**：默认单色、不补零、带单位；只有越界才提示颜色。
2. **核心动作 ≤2 次点击**：菜单栏 → HUD → 清理。
3. **结果用通知，模态只留给破坏性确认。**
4. **所有扫描都有阶段/进度/耗时，可取消。**
5. **空态给下一步，不出现大块空白。**
6. **中文直白**：不说「优化项」，说「可以清理的缓存」；界面中 HUD 统一称「状态面板」。
7. **悬浮层不抢焦点、不切 Space**（沿用 NSPanel + 非激活面板配方）。
8. **设置少而即时**：改完立刻见效并持久化。

### 1.4 用户旅程

| 场景 | 步骤 | 成功标准 | 对应界面 |
|---|---|---|---|
| 日常扫一眼 | 瞄菜单栏 → （必要时）点开状态面板看细节 | 1 秒内判断 CPU/内存/网络是否异常；菜单栏不刺眼 | 菜单栏、HUD |
| 磁盘告急 | 点菜单栏 → 清理 → 扫描 → 勾选 → 确认 → 看通知 | 10 秒内看到「能清多少」，清完有横幅 | HUD、主界面·清理 |
| 卸载应用 | 主界面 → 卸载 → 搜索 → 选中 → 扫描残留 → 勾选 → 确认 → 废纸篓 | 残留分类与大小准确；可从废纸篓恢复 | 主界面·卸载 |
| 装机第一次 | 双击打开 → 3 步引导（介绍/权限/自启+预设）→ 完成 | 只出现一次，可跳过，可重看；完成后菜单栏可点 | 引导窗口 |
| 想换样子 | 设置 → 面板与插件 → 安装插件 → 启用 | 装完无需重启即生效；非法插件被拒且回退 | 主界面·设置 |

---

## 2. 信息架构

### 2.1 三层结构

~~~
菜单栏（常驻，无 Dock 图标）
 └─ 左键：状态面板 HUD（400×520，非激活浮层）
 │    ├─ 头部：系统状态 / 实时 / 时钟
 │    ├─ 5 指标区（插件 v1 可替换为 rows 渲染）
 │    ├─ TOP 进程 3 行
 │    └─ 清理 / 卸载 / 主界面
 ├─ 右键：打开面板 / 打开主界面 / 设置… / 暂停采集 / 关于 / 退出
 └─ 打开主界面
      └─ 主窗口（960×660，可缩放）
           ├─ 清理
           ├─ 卸载
           ├─ 磁盘
           └─ 设置（菜单栏 / 面板与插件 / 通用 / 权限 / 关于）
~~~

### 2.2 窗口与导航规则

| 规则 | 要求 |
|---|---|
| 激活策略 | NSApplication.ActivationPolicy.accessory（LSUIElement=true），不出现在 Dock 与 Cmd+Tab |
| 主窗口 | 单实例；关闭不销毁（isReleasedWhenClosed=false）；再次打开复用 |
| 主窗口尺寸 | 默认 960×660；最小 760×520；可缩放；左侧栏固定 180 |
| 分区切换 | 侧栏四项互斥；记住上次分区（AppState.selectedSection，进程内；跨启动默认「清理」） |
| HUD | 单实例；点击菜单栏切换显示；点外部/Esc 收起；不激活 App、不切 Space |
| 关窗行为 | 关闭主窗口不退出 App；退出只能通过右键菜单「退出 Otter」或 Cmd+Q |
| 快捷键 | Cmd+Q 退出；Cmd+, 打开设置；Esc 收起 HUD |

### 2.3 数据流与刷新策略

| 层 | 职责 | 现有接口 |
|---|---|---|
| 采样层 | 2s 采样 SystemMetrics | MetricsSampling.sample()（dev-data 实现 RealMetricsSampler） |
| 状态层 | 主线程发布 metrics、窗口联动 | AppState（ObservableObject） |
| 服务层 | 清理/卸载/磁盘只读操作 | Services.shared.clean / uninstall（Bootstrap 注入） |
| 插件层 | 加载 HUD manifest | PluginStore.shared / Prefs.hudStyle |
| UI 层 | 菜单栏、HUD、主窗口、引导 | 各 Controller/View |

刷新频率（**必须**）：

| 状态 | 菜单栏 | HUD | 说明 |
|---|---|---|---|
| 全部窗口隐藏 | 2s | — | 空闲降频目标 P1：10s 或暂停 |
| HUD 可见 | 1s | 1s | 打开 HUD 立即刷新一次 |
| 主窗口可见 | 2s | — | 清理/卸载分区不依赖周期采样 |
| 采样被暂停 | 停止更新 | 停止更新 | 右键「暂停采集」P1 |

> 当前 AppState 固定 2s、HUD 时钟用 TimelineView 1s。达标需把采样间隔与 hudVisible 联动（见 D8）。

---

## 3. 菜单栏

### 3.1 形态与交互

- 使用 NSStatusItem（variableLength；极简预设用 squareLength）。
- 左键：切换 HUD；右键菜单实际项：打开面板、主界面、设置、暂停采集（暂停后变「恢复采集」）、欢迎引导…、关于 Otter、退出 Otter。
- 悬停 tooltip：单行摘要（格式见 9.1）；未就绪显示「Otter · 正在读取系统指标…」，暂停时前缀「采集已暂停 · 」。
- 点击到 HUD 可见 **≤150ms**（P0），目标 ≤80ms。
- 辅助功能描述：「Otter 系统状态」。
- 不弹 Dock、不抢焦点、不改菜单栏其他项目顺序。

### 3.2 四个预设

| id（Prefs.menuBarPreset） | 名称 | 内容 | 默认 | 适用 |
|---|---|---|---|---|
| minimal | 极简 | 仅水獭模板图标（water.waves，缺失回退 drop.fill），无文字；tooltip 看详情 | 否 | 不想被打扰 |
| dual | 双指标 | CPU + 内存：模板图标 + 数值，单空格分隔 | **是** | 大多数人 |
| single | 单指标+趋势 | Prefs.singleMetric 指定 1 个指标 + 8 格火花线（26×10pt） | 否 | 极客 |
| custom | 自定义 | 勾选 5 指标（showCPU/showMem/showDisk/showUp/showDown）；v1 固定渲染顺序 cpu → mem → disk → up → down | 否 | 高级用户 |

### 3.3 格式规范（硬规则）

| # | 规则 | 判定 |
|---|---|---|
| F1 | 百分比整数、**不补零** | 7% 不写 007%；100% 不写 100.0%；用 Fmt.percent 四舍五入，负值按 0、超出按 100 截断 |
| F2 | 速率**必须带单位** | 0B/s、820K/s、1.2M/s、1.5G/s；不截断 999.9；超过 1024 倍升级单位；用 Fmt.rate |
| F3 | **默认单色** | NSColor.labelColor；不得默认使用绿/黄/红 |
| F4 | 阈值色**仅当 colorByLoad=true** | <60 保持 labelColor；60–84.9 systemYellow；≥85 systemRed；**永不使用绿色**；上传/下载不参与着色 |
| F5 | 图标用 **SF Symbol 模板图** | isTemplate=true；CPU=cpu、内存=memorychip、磁盘=internaldrive、上传=arrow.up、下载=arrow.down；标题内 11×11pt，基线 -1.5 |
| F6 | 数字等宽 | 使用系统等宽数字（monospacedDigit），避免数值跳动引起宽度抖动 |
| F7 | 分隔 | 模块间单空格；无尾随空格；v1 不用竖线（P2 可选细竖线） |
| F8 | 无数据 | metrics.isReady=false 时数值显示「--」（不带 %），图标保留；isReady=true 且值为 0 → 显示 0% / 0B/s（0 是有效值，不等于未知） |
| F9 | 宽度 | 每个 tick 实测标题宽度；超预算按 3.4 降级；**禁止省略号截断数值** |
| F10 | 深浅色 | 全部走语义色 + 模板图；不硬编码黑/白；外观切换后 2s 内自动正确 |

**阈值色说明**：实现使用 systemYellow（与 ShellPrefs.menuBarColor 一致）；浅色菜单栏若黄色对比不足，可改为 systemOrange，但「≥85 才红、永不出现绿色」不可变。

### 3.4 宽度预算与降级

实现采用**整条预算 120pt**（ShellPrefs.menuBarWidthBudget），每次渲染实测标题宽度，超限逐级降级：

| 级 | 动作 | 适用 |
|---|---|---|
| L0 | 正常渲染 | 全部 |
| L1 | 去掉趋势火花线 | single |
| L2 | 只保留首个指标（custom 的顺序由 Prefs.menuBarOrder 决定；dual 保留 CPU） | dual / custom |
| L3 | 只保留水獭图标（等同极简，点击仍开 HUD） | 全部 |

- 触发：候选标题宽度 +2pt 余量 ≤120pt 才采用；否则尝试下一级。
- 降级不持久化；设置页「预览」在超限时提示：「宽度超出上限，已隐藏：{指标}」。
- 自定义选中 5 项时典型结果：只保留顺序中的第一个指标（默认 CPU）。
- 说明：L2 跳过「去图标」中间态是本轮实现取舍；若后续要显示 2–3 个指标，可在 L1 与 L2 之间增加「去图标」一级（P1 优化，见 D11）。
- 极简预设用 NSStatusItem.squareLength + 16pt 模板图标。

### 3.5 各预设渲染示例（文本化，图标以 [icon] 表示）

| 场景 | preset | 渲染 |
|---|---|---|
| 正常 | dual | [cpu]42% [mem]61% |
| 高负载开启着色 | dual | [cpu]87%（红） [mem]91%（红） |
| 单指标 | single | [cpu]42% ▁▂▄▆▅▃▂▁（8 格火花线） |
| 自定义 3 项 | custom | [cpu]42% [mem]61% [disk]18% —— 顺序固定 cpu→mem→disk |
| 极简 | minimal | [water.waves] |
| 未就绪 | dual | [cpu]-- [mem]-- |
| 速率 | single(down) | [arrow.down]1.5G/s ▁▁▂▄▇█▆▃ |

### 3.6 火花线（single）

- 8 个采样点，每 2s 推入一个点，覆盖最近 16s；新点从右进入，超出丢弃。
- 尺寸 26×10pt，单色（模板图/Template 绘制），柱宽 2pt、间距 1.5pt、底部对齐、最小高度 1pt。
- 百分比指标按 0–100 缩放；速率按窗口内最大值归一化（最小刻度 1K/s，全 0 时画平线）。
- 暂停采集时火花线冻结并降低不透明度。

### 3.7 持久化映射

| 设置项 | Prefs 键 | 默认 |
|---|---|---|
| 预设 | menuBarPreset | dual |
| 自定义指标 | showCPU / showMem / showDisk / showUp / showDown | true/true/false/false/false |
| 自定义顺序 | menuBarOrder（CSV） | cpu,mem,disk,up,down |
| 单指标选择 | singleMetric | cpu |
| 按负载着色 | colorByLoad | false |
| 自启 | launchAtLogin | 引导第 3 步默认开；底层默认 false（避免无引导环境自动注册） |
| 通知开关 | notificationsEnabled（Prefs 扩展，默认 true） | true |
| HUD 插件 | hudStyle | n1 |

---

## 4. 状态面板 HUD（400×520）

### 4.1 窗口规格

| 项 | 要求 |
|---|---|
| 尺寸 | **固定 400×520**（宽高不可缩放），内容恰好铺满，无滚动条 |
| 圆角/材质 | 圆角 16；NSVisualEffectView material .hudWindow（或 .popover），blendingMode .behindWindow，state .active |
| 面板 | NSPanel：borderless + nonactivatingPanel；level = CGWindowLevelForKey(.statusWindow)；collectionBehavior = canJoinAllSpaces + fullScreenAuxiliary；isMovable=false；hidesOnDeactivate=false；hasShadow=true；isOpaque=false；背景透明 |
| 定位 | 水平对齐 status item 中心；顶部 = 屏幕顶 - 菜单栏高度 - 4pt；左右至少留 8pt；使用按钮所在屏幕（多显示器） |
| 显示 | orderFrontRegardless + makeKey；不激活 App（不抢前台） |
| 关闭 | 点击面板外任意处；Esc；再次点击菜单栏 |
| 性能 | 点击到可见 ≤150ms；HUD 可见时 1s 刷新 |

### 4.2 布局总表（自上而下，inner padding 14，区块间距 10）

| # | 区块 | 内容 | 数据来源 | 参考高度 | 空态 | 加载态 |
|---|---|---|---|---|---|---|
| 1 | 头部 | 水獭图标 + 「系统状态」+ 状态点/文案 + 时钟 HH:mm:ss | 本地时钟；isReady | 20 | — | 状态点灰、「加载中」、时钟正常走 |
| 2 | CPU 卡 | 标签 CPU + 「N 核」+ 34pt 数值 + 进度条 | cpuPercent、coreCount | 88 | 数值 --、进度 0 | 数值 --、进度 0 |
| 3 | 内存 / 磁盘双卡 | 内存：数值 + 「x.x / y GB」+ 条；磁盘：数值 + 「x / y GB」+ 条 | memUsedPercent/Bytes/TotalBytes；diskUsedPercent/Bytes/TotalBytes | 96 | -- / -- GB | -- / -- GB |
| 4 | 网络卡 | 上传 / 下载 各一行：图标 + 速率 | upBytesPerSec、downBytesPerSec | 56 | -- | -- |
| 5 | TOP 进程 | 标题「TOP 进程 / 按 CPU」+ 最多 3 行：进程名 + CPU% | topProcesses（按 cpuPercent 降序取前 3） | 116 | 「暂无进程数据」 | 3 行骨架「正在读取进程…」 |
| 6 | 操作栏 | 清理 / 卸载 / 主界面 三个按钮 | Services 就绪状态、openMainSection/openMainWindow | 34 | 服务未就绪时清理/卸载禁用 | 同左 |

> 实现为「固定窗口 + 内容区纵向 ScrollView」：头部 22pt、上下内边距 12pt、区块间距 10pt，底部操作栏固定；内容超出时可滚动，不裁切、不压缩窗口。上表高度仅作视觉预算参考。

### 4.3 各区块细节

**① 头部**：左侧 water.waves 13pt secondary；「系统状态」13pt semibold；状态点 6pt：绿=实时监控中（isReady 且未暂停）、灰=读取中（!isReady）、橙=已暂停；状态文案「实时监控中 / 读取中… / 已暂停」11pt secondary；右侧时钟 11pt monospaced「HH:mm:ss」。

**② CPU 卡**：标签 11pt secondary，右侧「8 核」；数值 34pt rounded semibold monospacedDigit（用 Fmt.percent）；进度条 tint：≥85 红、≥60 橙、否则绿。

**③ 内存/磁盘双卡**：标题 11pt；数值 26pt；副标题 10pt secondary；内存副标题格式「8.2 / 16 GB」（%.1f / %.0f GB），磁盘「89 / 500 GB」（%.0f / %.0f GB）；总量为 0 时显示「-- / -- GB」；进度条内存蓝色、磁盘绿色，≥85 转红。

**④ 网络卡**：上传（arrow.up 紫）/下载（arrow.down 青）各一列，标签 10pt secondary，数值 13pt medium monospacedDigit；0 显示 0B/s。

**⑤ TOP 进程**：仅 CPU 排序；每行：进程名 12pt（最多 1 行，超长截断加省略号）+ 右侧 CPU% 11pt mono secondary；行不可点击（v1 无进程分区，不做假入口）；hover tooltip 显示完整名称与内存（Fmt.bytes）。超过 3 个只显示前 3。

**⑥ 操作栏**：三枚等宽按钮，高约 30；「主界面」为主按钮（accent 填充），清理/卸载为次级按钮。清理/卸载在 Services.shared.clean/uninstall 为 nil 时禁用，tooltip「服务未就绪」。点击后打开主界面对应分区并收起 HUD。

### 4.4 视觉与可访问性

- 全部文字用语义色（primary/secondary/tertiary），tile 背景用 primary 叠加 6% 一类动态色，**不得用 white.opacity**（浅色模式会不可见）。
- 深浅色：面板材质自动适配；边框颜色用 separator 一类动态色。
- VoiceOver：面板为「系统状态面板」；数值需带标签（如「CPU 42%」）；按钮有明确标签。
- 不用 emoji 作为功能图标；不用彩色品牌图（水獭仅头部小图标，可接受单色模板）。

### 4.5 状态与刷新

| 状态 | 进入条件 | 表现 |
|---|---|---|
| 加载中 | isReady=false | 数值 --，灰点，骨架卡片 |
| 实时监控中 | isReady=true 且未暂停 | 绿点、数值随采样更新 |
| 已暂停 | 右键「暂停采集」 | 橙点、文案「已暂停」、数值与趋势冻结 |

HUD 可见时立即触发一次采样；当前采样周期 2s（目标 1s，D8）；时钟与趋势由 1s 定时驱动。收起后回到 2s（空闲降频目标 10s，P1）。

---

## 5. 主界面（960×660）

### 5.1 框架

- 左侧栏 180pt：产品名 Otter（17pt semibold）+ 四项（清理 sparkles / 卸载 xmark.bin / 磁盘 internaldrive / 设置 gearshape），选中态圆角高亮。
- 右侧内容区：标题 22pt semibold + 一句副标题（12pt secondary）+ 内容；内容区内边距 22；可滚动。
- 顶部无工具栏；标题栏透明（titlebarAppearsTransparent）。
- 服务未就绪（Services.shared.clean/uninstall 为 nil）时，清理/卸载分区顶部显示黄色提示条：「数据服务未就绪 / 请重新构建后重试；清理与卸载暂不可用。」
- 所有网络请求：无；所有删除：废纸篓；所有破坏性操作：模态二次确认。

### 5.2 清理分区

**流程状态机**

| 状态 | 界面 | 可用操作 | 进入条件 | 退出 |
|---|---|---|---|---|
| idle | 空态卡片（sparkles 图标 + 标题 + 说明 + 主按钮） | 开始扫描 | 进入分区 | 点扫描 → scanning |
| scanning | 不确定进度条 + 阶段文案 + 可滚动流式日志区 + 已用时间；「开始扫描」禁用，防重复触发 | 取消 | preview 开始 | 完成 → preview；取消 → idle；失败 → failed |
| preview | 总可释放大小 + 分类列表（可展开、三态勾选）+ 全选 + 「清理 X」 | 勾选/展开/全选/清理/重新扫描 | 扫描成功且有可清项 | 清理 → confirming；重扫 → scanning |
| confirming | 模态确认（唯一的破坏性确认） | 取消 / 清理 | 点清理且已选 >0 | 清理 → running；取消 → preview |
| running | 不确定进度 + 阶段 + 最近日志 + 已用时间 | 取消 | 确认清理 | 完成 → done；失败 → failed；取消 → cancelled |
| done | 结果卡（释放大小）+ 再次扫描 | 再次扫描 | run 成功 | 再次扫描 → scanning |
| empty | 「没有需要清理的内容」+ 再扫一次 | 再扫一次 | 扫描成功但 0 项 | 再扫 → scanning |
| failed | 错误卡（原因）+ 重试 + 复制日志 | 重试/复制 | 服务报错 | 重试 → scanning |
| cancelled | 「已取消」+「没有删除任何文件」+ 返回 | 返回 | 用户取消 | 返回 → idle |

**交互细则**

1. 扫描只调用 preview()（mole clean --dry-run），**绝不做任何写操作**；扫描期间可取消，取消后回到 idle。
2. 预览数据：CleanPlan.categories → 每个 CleanCategory 显示 title、bytes（Fmt.bytes）、items.count；展开显示 CleanItem.label + bytes。
3. 勾选：分类三态（全选/部分/未选）；默认全选；取消部分子项时分类变 indeterminate；顶部总大小只统计已勾选；勾选为 0 时「清理」禁用。
4. 全选/取消全选一键操作；分类默认折叠，可展开；项目超过 200 条时列表内滚动。
5. 确认弹窗文案见 9.3；确认后调用 run()；运行中显示 CleanProgress.phase 与 line（取最后一行，单行截断）。
6. 成功后：内联结果 + 系统通知（见第 7 章）；失败：内联错误 + 复制日志（rawText/output）到剪贴板。
7. 耗时：首次 dry-run 的真实成本约 **2–3 分钟**（mole 扫描整机缓存）；扫描期间必须流式输出 mole 日志（可滚动、自动跟随底部），并禁用「开始扫描」按钮防止重复扫描；扫描 3 秒后显示「首次扫描较慢，请稍候」提示。完成后恢复按钮并展示预览。
8. 红线：自动验收只测 preview；run 仅人工测试，且必须在确认弹窗点「取消」验证取消路径。

### 5.3 卸载分区

**布局**：左右分栏（列表 260 / 详情自适应）。列表：搜索框 + 排序（名称/位置）+ 应用行（图标 32 + 名称 + 路径缩略）。详情：应用头（大图标 + 名称 + 路径 + bundleId）+ 扫描按钮 + 残留分组 + 底部操作。

**流程状态机**

| 状态 | 界面 | 可用操作 |
|---|---|---|
| loading | 列表骨架 / 加载指示 | — |
| list | 应用列表（默认按名称 localised 排序） | 搜索/排序/选中 |
| empty | 「没有找到可卸载的应用」 | 刷新 |
| scanning | 详情区「正在查找残留…」不确定进度 | 取消（可选） |
| scanned | 残留分组（缓存/偏好设置/应用数据/日志/状态）+ 每项路径与大小 + 全选 | 勾选/全选/移入废纸篓 |
| confirming | 模态确认（应用本体 + 已勾选残留 + 总大小） | 取消/移入废纸篓 |
| running | 「正在移入废纸篓…」 | — |
| done | 结果卡 + 列表刷新 | 完成 |
| partial | 「部分项目未能移入废纸篓」+ 重试 | 重试/完成 |
| failed | 错误卡 + 重试 | 重试 |

**交互细则**

1. 进入分区即 listApps()；失败显示错误卡（原因 + 重试）。
2. 搜索按名称/bundleId 子串不区分大小写；无结果给「清除搜索」。
3. 排序：名称（默认，localizedStandardCompare）、位置（/Applications 在前）。不提供「大小」排序（AppItem 无大小字段，扫描后才有）。
4. 选中应用后点「扫描关联残留」→ scan(app)；扫描结果按 LeftoverItem.kind 分组，kind 到中文映射：**app→应用本体（固定置顶）**、cache→缓存、prefs→偏好设置、data→应用数据、logs→日志、state→状态；未知 kind 原样显示。实现中应用本体作为 kind=app 的 LeftoverItem 放进 UninstallScan.leftovers，随 trash(items) 一起移入废纸篓。
5. 默认全选残留（含应用本体）；总大小 = 已选项之和（本体 + 残留）。建议禁止取消勾选应用本体（若实现允许，记 P1 缺陷）。
6. 确认弹窗必须写明「可以从废纸篓恢复」；确认后调用 trash(items)；服务返回成功计数。
7. 成功后列表刷新、清空详情、发通知；部分失败保留详情并标出失败项。
8. 守护：系统应用/受保护应用（Safari、系统工具等）不显示或显示「受保护」并禁用卸载；应用消失 → 「应用已不存在」+ 刷新。
9. 红线：自动验收不做真实删除；只测取消、受保护、不存在、空残留等守护路径。真实 trash 仅用自制临时测试 app 人工验证，验证后从废纸篓恢复。

### 5.4 磁盘分区

**布局**：顶部容量卡（整行）：已用/总量/百分比 + 进度条 + 剩余；下方工具栏：「选择目录…」+ 快捷 chips（主目录/下载/应用程序/资源库）+「开始分析」；结果区：路径面包屑 + 表格（名称/大小/占比）+ 行下钻。

| 状态 | 界面 | 操作 |
|---|---|---|
| idle | 容量卡 + 空态引导 | 选择目录/快捷路径/开始分析 |
| scanning | 当前目录 + 已扫描文件夹数 + 已用时间（不确定进度） | 取消 |
| result | 面包屑 + 按大小降序的条目表 + 占比条 | 下钻/返回上级/在 Finder 中显示 |
| empty | 「这个目录是空的」 | 返回上级 |
| denied | 「没有权限读取…」+ 打开系统设置 | 去设置/重试 |
| failed | 错误卡 + 重试 | 重试 |

**交互细则**

1. 容量卡数据来自 SystemMetrics.diskUsedBytes/diskTotalBytes/diskUsedPercent；总量未知显示 --。
2. 分析为只读扫描（目录大小聚合），不删除、不移动；取消立即停止并保留已扫描结果（可选）。
3. 默认目录：主目录（~）；快捷 chips 一键切换并立即分析。
4. 只显示前 500 项，超出提示「文件太多，只显示前 500 项」；目录行可双击进入，文件行可「在 Finder 中显示」。
5. 权限失败给出 FDA 引导；不确定项标注「无法读取」而不是 0B。
6. treemap 列为 P2，v1 不做。

**实现说明**：本轮磁盘分析由 DiskView 内部的只读扫描器实现（未抽独立服务协议），不修改 Services.swift；语义与行为要求不变。后续若抽出 DiskServicing，接口风格对齐 CleanServicing。磁盘分区必须可进入、不崩溃；分析未就绪时展示容量卡 + 引导文案。

### 5.5 设置分区

分区内按分组纵向排列，每组卡片：标题 13pt semibold + 行（左侧主文案/说明，右侧控件）。

| 分组 | 控件 | 行为与持久化 |
|---|---|---|
| 菜单栏 | 预设 4 选 1（极简/双指标/单指标+趋势/自定义） | 写 menuBarPreset，菜单栏 2s 内更新 |
| 菜单栏 | 自定义时：5 个指标开关 + 顺序调整 | 写 showCPU/showMem/showDisk/showUp/showDown + menuBarOrder（CSV） |
| 菜单栏 | 单指标时：指标下拉（CPU/内存/磁盘/上传/下载） | 写 singleMetric |
| 菜单栏 | 「按负载着色」开关 + 说明「仅在 ≥85% 时变红，平时保持单色」 | 写 colorByLoad |
| 菜单栏 | 预览条：按当前设置渲染真实标题（静态示意）+ 降级提示 | 只读；数据来自当前 metrics |
| 通用 | 「登录时自动启动」开关 | LoginItem.setEnabled；失败回滚开关并内联报错 |
| 通用 | 系统通知：开关（notificationsEnabled，默认开）+「发送测试」+ 授权状态/「去设置」 | 写 notificationsEnabled；发送测试用 Notifications.post；授权状态读系统 |
| 面板与插件 | 内置面板 n1/n8 卡片 + 用户插件列表（名称/版本/作者/ID） | 单选启用；写 Prefs.hudStyle + PluginStore.activeId |
| 面板与插件 | 「从文件夹安装…」「打开插件目录」 | 见第 8 章流程 |
| 面板与插件 | 「删除」（仅用户插件）、「恢复默认」 | 移入废纸篓；当前插件被删则回退 n1 |
| 权限 | 通知 / 登录项 / 全磁盘访问 三行状态 + 「去设置」 | 状态实时读取；FDA 用受保护路径可读性启发式判断，无法判断显示「未知」 |
| 关于 | 图标、名称、版本 0.2.0（构建 1）、内置 mole 路径/版本、版权 | 只读 |
| 关于 | 「重新查看引导」 | 打开引导窗口（不影响 otterOnboarded） |
| 关于 | 「退出 Otter」 | NSApp.terminate |

**通用要求**：修改即时生效并持久化；不需要「保存」按钮；控件禁用时给出原因 tooltip；任何失败在行内显示，不用模态（破坏性确认除外）。

### 5.6 空态/加载/错误通用规则

- 每个异步操作三态齐全：加载（骨架或不确定进度）、空（给下一步）、错误（原因 + 重试）。
- 错误文案必须包含：发生了什么 + 用户能做什么；禁止只显示错误码或英文原文。
- 不出现无限转圈：超过 30s 的扫描显示「仍在进行…」与取消入口。
- 不使用占位假数据；未就绪显示占位符并说明。

---

## 6. 首启引导（3 步）

### 6.1 触发与生命周期

- 触发：首次启动且 UserDefaults「otterOnboarded」不为 true。
- 窗口：独立 NSWindow，620×480，居中，可关闭（等同跳过）；顶部为「Otter / 设置向导」，步进显示「第 N / 3 步」。
- 只出现一次：完成或跳过都写入 otterOnboarded=true。
- 可重看：设置→关于→「重新查看引导」；重看模式不写标记、按钮显示「关闭」。
- 引导期间 App 不打开主窗口（替代现有「首次启动打开设置页」的占位行为）。

### 6.2 三步内容

| 步 | 标题 | 正文/内容 | 主按钮 | 次按钮 |
|---|---|---|---|---|
| 1/3 介绍 | 抬眼看得到，低头两下清干净 | 「Otter 常驻菜单栏、不占 Dock。点一下獭图标，面板就在菜单栏下方展开。」+ 三条要点：菜单栏 5 指标（CPU/内存/磁盘/上传/下载，默认单色，越界才变色）、HUD 面板（5 指标 + TOP3 + 清理/卸载入口）、主界面四分区（清理/卸载/磁盘/设置） | 继续 | 跳过 |
| 2/3 权限 | 给 Otter 两个权限 | ① 全磁盘访问：扫描缓存、卸载残留、磁盘分析需要读取受保护目录；② 系统通知：清理/卸载完成后发横幅；说明「都可在系统设置里随时改；先跳过也能用，只是部分功能受限」+「在系统设置里勾选 Otter 后返回本窗口，状态会自动刷新」 | 继续 | 上一步 |
| 3/3 自启+预设 | 最后两步 | ①「登录时自动启动」（默认开，说明「重启后菜单栏仍有 Otter」）；② 菜单栏显示：预设 4 选 1 + 趋势指标；说明「以后随时可以在「设置」里修改」 | 完成 | 上一步 |

- 步进指示：圆点 +「第 N / 3 步」；第 2 步只展示权限状态与跳转，不强制授权。
- 完成：写 otterOnboarded=true；按开关应用 LoginItem；应用预设/趋势指标；关闭窗口。不弹庆祝、不自动打开主窗口。
- 跳过/点关闭：写 otterOnboarded=true，直接关闭。
- 失败：登录项注册失败 → 行内提示「无法开启自动启动，可在设置中重试」，不阻塞完成。
- **实现偏差**：当前 OnboardingModel 用 Prefs.launchAtLogin（默认 false）初始化开关，导致第 3 步默认关；按需求应为默认开（见 D12，P0 待修）。

---

## 7. 系统通知

### 7.1 授权与降级

- 首次启动（或引导第 2 步）请求 UNUserNotificationCenter 授权（alert + sound）。
- 已拒绝/未授权：不发系统通知；结果仍在内联展示；设置页显示状态与「去设置」。
- 所有通知仅本地、内容不含隐私路径；点击通知打开主界面对应分区（清理/卸载）。
- 通知在 App 未激活时也可见；同一操作只发一条。

### 7.2 文案表

| 场景 | 标题 | 正文 | 点击行为 |
|---|---|---|---|
| 清理成功 | 清理完成 | 已释放 {大小} 空间。 | 打开主界面·清理 |
| 清理成功但 0 字节 | 清理完成 | 已释放 0 B 空间。 | 打开主界面·清理 |
| 清理失败 | 清理没有完成 | {原因}；为空时回退「请稍后重试，或在主界面查看日志。」 | 打开主界面·清理 |
| 卸载成功 | 卸载完成 | {应用名} 及其残留已移入废纸篓，共 {大小}。 | 打开主界面·卸载 |
| 卸载失败 | 卸载没有完成 | {原因}；为空时回退「{应用名} 未能移入废纸篓，请重试。」 | 打开主界面·卸载 |
| 设置测试 | Otter 通知测试 | 通知已开启，清理与卸载完成后会在这里提醒你。 | 无（仅验证通道） |

- 占位符：{大小} 用 Fmt.bytes；{应用名} 为应用显示名；{原因} 为中文可读原因（≤40 字）。
- 点击跳转通过 content.userInfo["section"] = clean/uninstall 实现；在 App 前台时也显示 banner。
- 频控：10 秒内同类成功通知合并为一条（后到覆盖）；失败通知不合并（P2，未实现）。
- **实现偏差**：CleanView/UninstallView 当前成功时直接 post 简化文案，失败时只做内联提示、未发通知；Notifications 已提供 postCleanFailed/postUninstallFailed，需统一到本节（S3，见 D14）。
- 暂停采集、切换预设、安装插件不发系统通知。

---

## 8. 插件 v1（声明式 HUD manifest）

### 8.1 范围与安全边界

- v1 **只做 HUD（状态面板）插件**；菜单栏插件为 v2。
- 插件是纯声明式 JSON：**不执行任何代码、不联网、不读文件、不自定义颜色/字体/HTML**。
- 宿主只把白名单指标注入预定义行样式；插件不能改变窗口尺寸、按钮、头部、通知、菜单栏。
- 内置 n1/n8 也以同一个 manifest 契约提供（dogfooding）。

### 8.2 目录与文件

~~~
用户插件（可写）
~/Library/Application Support/Otter/plugins/
  com.example.focus/
    manifest.json        # 推荐：目录名 = manifest.id
  任意名称.json           # 兼容：直接散落在插件目录下的单文件

内置插件（只读，随 App）
Otter.app/Contents/Resources/plugins/
  n1.json
  n8.json
~~~

- 用户插件两种布局都加载：子目录内的 manifest.json（推荐），或插件目录下的散落 *.json。
- 内置插件为扁平 JSON 文件，按文件名排序加载；Resources 缺失时用程序内置 manifest 兜底（n1/n8 始终可用）。
- 用户同 id 会覆盖内置（当前实现行为，见 D13 安全缺口）；内置文件本身不被修改。
- 目录名/文件名不要求等于 id，但安装目标目录固定为 manifest.id。
- 安装时会把整个来源目录复制到目标目录（v1 不执行其中任何文件；插件只读取 manifest.json）。
- 用户目录不存在时由安装/打开目录流程自动创建。

### 8.3 manifest 字段

| 字段 | 必填 | 类型 | 约束 | 默认/说明 |
|---|---|---|---|---|
| id | 是 | string | 1–48 字符；首字符为字母/数字；其余可用字母、数字、点、下划线、连字符；不得含斜杠/空格（实现正则：^[A-Za-z0-9][A-Za-z0-9._-]{0,47}$） | 与 HUDPlugin.id 对应；安装目录名；大小写敏感 |
| name | 是 | string | 去空白后非空，≤60 字符 | 设置页显示名 |
| version | 是 | string | 去空白后非空，≤24 字符（不强制 semver） | 仅展示与覆盖判断 |
| author | 否 | string | 任意字符串（建议 ≤32） | 设置页展示 |
| width | 否 | number | 200–1600 | v1 忽略，宿主固定 400 |
| height | 否 | number | 200–1600 | v1 忽略，宿主固定 520 |
| radius | 否 | number | 0–64 | 默认 16（n8 内置为 22） |
| rows | 是 | array | 1–24 项 | 顺序即渲染顺序 |

rows 元素：

| 字段 | 必填 | 类型 | 约束 |
|---|---|---|---|
| metric | 是 | enum | cpu / mem / disk / up / down / procs / clock / uptime |
| style | 是 | enum | big / bar / ring / text / divider |
| label | 否 | string | ≤40 字符；省略/null 视为未填；默认见下表 |

默认 label：cpu→CPU、mem→内存、disk→磁盘、up→上传、down→下载、procs→TOP 进程、clock→当前时间、uptime→已开机。

> 与 Core/Plugins.swift 对齐：HUDPluginRow.id = metric + ":" + style，因此同一插件内 metric+style 组合必须唯一，否则视为 ID 冲突拒绝安装。

### 8.4 行样式渲染语义

| style | 渲染 | 不适用/合并规则 |
|---|---|---|
| big | 卡片：图标+标签+副标题，32pt 数值 + 60 点火花线 | 速率/时钟/开机/进程按 MetricKind 渲染（不显示错误占位） |
| bar | 卡片：标签 + 数值 + 4pt 进度条（百分比指标） | 速率/时钟/开机/进程 → 仍显示数值，无进度条（不报错） |
| ring | 卡片：圆环进度 + 中心数值 | 非百分比指标 → 按文本数值显示 |
| text | 纯文本行；**相邻 text 行自动合并成一张卡** | 未知 metric 行被忽略 |
| divider | 1px 分隔线（忽略 metric） | — |
| procs | 渲染 TOP3 进程卡（标题「占用最高进程」/「按 CPU」） | 未声明 procs 时宿主自动在末尾补一张 TOP3 卡 |
| clock | 时间卡（HH:mm:ss） | — |
| uptime | 开机时长卡（Fmt.uptime） | — |

- 头部（系统状态/实时/时钟）与底部操作栏（清理/卸载/主界面）由宿主固定；插件只替换中间内容区。
- 内容区使用纵向 ScrollView：行数多时滚动，不裁切窗口、不显示「未显示」提示（v1 实现如此）。
- 渲染使用语义色/系统字体；插件不能指定颜色与图标；未知 metric/style 在加载校验阶段拒绝（见 8.5）。

### 8.5 校验规则

| 码 | 规则 | 处理 |
|---|---|---|
| V1 | JSON 可解码为 HUDPlugin；未知字段忽略（前向兼容）；文件大小 ≤64KB（建议，当前未强制） | 解码失败拒绝 |
| V2 | id/name/version/rows 必填且非空 | 拒绝 |
| V3 | id 匹配 ^[A-Za-z0-9][A-Za-z0-9._-]{0,47}$ | 拒绝 |
| V4 | rows 1–24 且非空 | 拒绝 |
| V5 | width/height ∈ 200–1600；radius ∈ 0–64 | 拒绝 |
| V6 | metric ∈ cpu/mem/disk/up/down/procs/clock/uptime | 拒绝 |
| V7 | style ∈ big/bar/ring/text/divider | 拒绝 |
| V8 | label 省略/null 或 ≤40 字符 | 拒绝 |
| V9 | 同插件 metric+style 重复（当前未校验） | 建议拒绝，v1 允许 |
| V10 | 非 manifest.json 的文件不读取、不执行（安装时可能随目录复制） | 接受 |
| V11 | id 与内置 n1/n8 相同 | **产品要求拒绝；当前实现会覆盖内置（D13）** |
| V12 | 单个插件解码/校验失败只跳过该插件并记入 loadErrors，不影响其他插件与 HUD | 接受 |

### 8.6 示例 manifest

~~~json
{
  "id": "com.example.devpanel",
  "name": "开发者面板",
  "version": "1.0.0",
  "author": "Otter 用户",
  "width": 400,
  "height": 520,
  "radius": 16,
  "rows": [
    { "metric": "cpu", "style": "big", "label": "处理器" },
    { "metric": "mem", "style": "bar", "label": "内存" },
    { "metric": "disk", "style": "bar", "label": "磁盘" },
    { "metric": "up", "style": "text", "label": "上传" },
    { "metric": "down", "style": "text", "label": "下载" },
    { "metric": "uptime", "style": "text", "label": "已开机" },
    { "metric": "clock", "style": "divider" },
    { "metric": "procs", "style": "text", "label": "占用最高" }
  ]
}
~~~

内置 n1（瓷砖网格，线性化）：cpu big、mem bar、disk bar、up text、down text、procs text。
内置 n8（胶囊速览，线性化）：cpu big、mem bar、disk bar、up text、down text（manifest 未声明 procs，渲染时宿主自动补 TOP3 卡）。
> 说明：v1 渲染为单列行式布局，内置 n1/n8 不追求与旧 WebView 网格逐像素一致（见 D6）。

### 8.7 安装流程

1. 设置 → 面板与插件 →「从文件夹安装…」→ NSOpenPanel（可选目录或单个 manifest.json 文件）。
2. 目录来源必须含 manifest.json；文件来源后缀必须为 .json，否则报「目录内缺少 manifest.json」/「请选择插件文件夹，或 manifest.json 文件」。
3. 解码 + 按 8.5 校验；失败 → 弹窗「无法安装插件」，显示 PluginError.localizedDescription（中文原因），不写入任何文件。
4. 目标 = 用户插件目录/<id>；已存在同 id 且用户未确认覆盖 → 抛 alreadyInstalled「已安装同 id 插件「x」，可覆盖安装」；确认覆盖后删除旧目录再复制。
5. 复制策略：来源为目录时整目录复制；来源为单文件时创建目标目录并复制为 manifest.json。**当前实现先删旧版再复制，非原子**（D15）；若复制失败，旧版本可能丢失。
6. reload 后**自动启用**：activeId = 新插件 id（无需二次确认），HUD 立即重绘；设置页选中态更新。
7. 全程不联网、不执行插件文件、不读取除 manifest.json 外的内容。

### 8.8 启用 / 停用 / 删除 / 回退

| 操作 | 行为 |
|---|---|
| 启用 | 单选：PluginStore.activeId = id（并写入 Prefs.hudStyle）；HUD 立即重绘 |
| 停用/恢复默认 | 「恢复默认」= 启用 n1；不删除用户插件 |
| 删除（用户插件） | 二次确认 → **直接移除目录**（不走废纸篓，插件可重装）→ 若删除的是当前启用项，自动回退到第一个可用插件（通常 n1） |
| 删除内置 | 禁止，lastActionError 显示「内置面板不可删除」 |
| 启动加载失败 | activeId 对应插件缺失/损坏 → 回退到第一个可用插件（通常 n1），loadErrors 记录并 NSLog |
| 运行中插件被外部删除 | v1 不监听文件系统；下次启动回退 |
| 用户 id 与内置相同 | 当前会覆盖内置；且 isBuiltin 判定为 true，导致该用户插件无法删除（D13，P0 需修） |
| 单行渲染异常 | 未知 metric 已在加载期拒绝；运行期异常行忽略，不影响其他行与窗口 |

### 8.9 错误码与文案

> P 码仅用于验收编号；UI 实际显示 PluginError.localizedDescription（中文）。

| 码 | 中文原因（实现文案） |
|---|---|
| P001 | 未找到插件文件/目录 |
| P002 | JSON 解析失败（{文件名}）：{解码错误} |
| P003 | 目录内缺少 manifest.json |
| P004 | id 只能包含字母/数字/._-，且 1–48 字符（当前「{id}」） |
| P005 | name 不能为空且不超过 60 字符 / version 不能为空且不超过 24 字符 |
| P006 | rows 需要 1–24 行 |
| P007 | width 需在 200–1600 之间 / height 需在 200–1600 之间 / radius 需在 0–64 之间 |
| P008 | 第 {N} 行 metric「{值}」不支持 / style「{值}」不支持 |
| P009 | 第 {N} 行 label 不超过 40 字符 |
| P010 | 已安装同 id 插件「{id}」，可覆盖安装 |
| P011 | 内置面板不可删除 |
| P012 | 文件操作失败：{原因} |

---

## 9. 全部界面中文文案表

> 标点统一用中文全角；数字与单位之间不加空格（1.2M/s；容量按 Fmt.bytes 输出，如 89 GB）；英文技术名（CPU、TOP、GB）保留。

### 9.1 菜单栏 / 右键菜单 / tooltip

| 位置 | 文案 |
|---|---|
| 菜单栏 | 无文字，仅图标+数值（数值格式见 F1/F2） |
| tooltip 正常 | 单行：CPU 42% · 内存 61% · 磁盘 18% · 上传 820K/s · 下载 1.2M/s · 已开机 3天14小时 · 8 核 |
| tooltip 加载 | 正在读取系统数据… |
| tooltip 暂停 | 采集已暂停，点击恢复 |
| 右键菜单 | 打开状态面板、打开主界面、设置…、暂停采集（P1）、关于 Otter、退出 Otter |
| 空态 | 数值显示「--」「-- / -- GB」 |

### 9.2 HUD

| 位置 | 文案 |
|---|---|
| 头部 | 系统状态 / 实时监控中 / 读取中… / 已暂停 |
| CPU 卡 | CPU / {N} 核 / {N}% |
| 内存卡 | 内存 / {N}% / {x.x} / {y} GB / -- / -- GB |
| 磁盘卡 | 磁盘 / {N}% / {x} / {y} GB / -- / -- GB |
| 网络卡 | 上传 / 下载 / 0B/s / -- |
| TOP 进程 | TOP 进程 / 按 CPU / 正在读取进程… / 暂无进程数据 |
| 操作栏 | 清理 / 卸载 / 主界面 / 服务未就绪（tooltip） |
| 辅助功能 | 系统状态面板；CPU {N}% |

### 9.3 主界面

**通用**

| 位置 | 文案 |
|---|---|
| 窗口标题 | Otter |
| 侧栏 | 清理 / 卸载 / 磁盘 / 设置 |
| 服务未就绪 | 数据服务未就绪 / 请重新构建后重试；清理与卸载暂不可用。 |

**清理**

| 位置 | 文案 |
|---|---|
| 标题/副标题 | 清理 / 扫描缓存和临时文件，扫完再决定清理什么。 |
| 空态标题 | 先扫一遍，看看能清多少 |
| 空态说明 | 只扫描，不会删除任何文件。 |
| 空态按钮 | 开始扫描 |
| 空态提示 | 首次扫描大约需要 2–3 分钟 |
| 扫描中 | 正在扫描… / 正在检查：{阶段} / 已用 {N} 秒 / 取消 / 首次扫描较慢，请稍候 / 扫描进行中不可重复扫描（按钮禁用） |
| 预览头 | 可清理 {大小} / {N} 个分类 · {M} 个项目 / 全选 / 取消全选 |
| 分类 | {分类名} {N} 项 {大小} |
| 主按钮 | 清理 {大小} |
| 次要按钮 | 重新扫描 |
| 确认标题 | 确认清理 {大小}？ |
| 确认正文 | 将清理 {N} 个分类中的 {M} 个项目，清理后无法恢复。缓存通常会自动重建，不影响应用数据。 |
| 确认按钮 | 取消 / 清理 |
| 运行中 | 正在清理… / 已完成：{日志行} / 取消 |
| 成功 | 清理完成 / 已释放 {大小} / 再次扫描 |
| 无内容 | 没有需要清理的内容 / 当前缓存已经很少了。 / 再扫一次 |
| 失败 | 清理未完成 / {原因} / 重试 / 复制日志 |
| 已取消 | 已取消 / 没有删除任何文件。 / 返回 |
| 日志面板 | 扫描日志 / 复制 / 关闭 |

**卸载**

| 位置 | 文案 |
|---|---|
| 标题/副标题 | 卸载 / 卸载应用，并找出它留下的缓存和偏好设置。 |
| 搜索 | 搜索应用 |
| 排序 | 名称 / 位置 |
| 列表加载 | 正在读取应用列表… |
| 列表空 | 没有找到可卸载的应用 / 只能卸载「应用程序」文件夹中的应用。 |
| 搜索空 | 没有匹配「{关键词}」的应用 / 清除搜索 |
| 详情按钮 | 扫描关联残留 |
| 扫描中 | 正在查找残留… |
| 无残留 | 没有发现关联残留 |
| 分组 | 缓存 / 偏好设置 / 应用数据 / 日志 / 状态 / 其他 |
| 应用本体行 | 应用本体 / {大小} / 随卸载一起移入废纸篓 |
| 汇总 | 已选 {N} 项 · {大小} |
| 主按钮 | 移入废纸篓 |
| 确认标题 | 确认卸载「{应用名}」？ |
| 确认正文 | 应用本体和 {N} 项残留（共 {大小}）将移入废纸篓，可以从废纸篓恢复。 |
| 确认按钮 | 取消 / 移入废纸篓 |
| 运行中 | 正在移入废纸篓… |
| 成功 | 卸载完成 / 「{应用名}」和 {N} 项残留已移入废纸篓。 / 完成 |
| 部分失败 | 部分项目未能移入废纸篓 / 有 {N} 项残留需要手动处理。 / 重试 / 完成 |
| 受保护 | 该系统应用受保护，无法卸载 / Safari、系统工具等不能通过 Otter 卸载。 |
| 不存在 | 应用已不存在 / 可能已被移动或删除。 / 刷新列表 |
| 权限 | 无法读取某些目录 / 已跳过 {N} 项。可在系统设置中授予全磁盘访问后重试。 / 打开设置 |
| 失败 | 卸载失败 / {原因} / 重试 |

**磁盘**

| 位置 | 文案 |
|---|---|
| 标题/副标题 | 磁盘 / 看看空间都去哪了。 |
| 容量 | 已用 {大小} / {总量} / 剩余 {大小} / 已用 {N}% |
| 快捷路径 | 主目录 / 下载 / 应用程序 / 资源库 |
| 工具栏 | 选择目录… / 开始分析 / 取消 |
| 扫描中 | 正在分析 {目录} / 已扫描 {N} 个文件夹 / 已用 {N} 秒 |
| 结果头 | {目录} · 共 {大小} / 按大小排序 |
| 表头 | 名称 / 大小 / 占比 |
| 空态 | 还没有分析结果 / 选择一个目录，看看里面最占空间的是什么。 |
| 目录空 | 这个目录是空的 |
| 权限 | 没有权限读取「{目录}」 / 请在系统设置 → 隐私与安全性 → 全磁盘访问中允许 Otter。 / 打开系统设置 |
| 截断 | 文件太多，只显示前 500 项 |
| 操作 | 在 Finder 中显示 / 返回上一级 |
| 未开放（降级） | 磁盘分析暂不可用 / 当前版本只显示容量信息。 |

**设置**

| 位置 | 文案 |
|---|---|
| 分区标题/副标题 | 设置 / 改完立即生效。 |
| 分组 | 菜单栏 / 通用 / 面板与插件 / 权限 / 关于 |
| 菜单栏显示 | 菜单栏显示 |
| 预设 | 极简 / 双指标 / 单指标+趋势 / 自定义 |
| 预设说明 | 极简：只显示水獭图标；双指标：CPU + 内存；单指标+趋势：一个指标加 8 格趋势；自定义：自己选指标。 |
| 自定义指标 | CPU / 内存 / 磁盘 / 上传 / 下载 |
| 固定顺序提示 | 当前版本按 CPU → 内存 → 磁盘 → 上传 → 下载 的顺序显示。 |
| 指标选择 | 显示指标 |
| 着色 | 按负载着色 / 仅在 ≥85% 时变红，平时保持单色。 |
| 预览 | 预览 / 预览不可用（数据未就绪）。 |
| 降级提示 | 宽度超出上限，已隐藏：{指标列表} |
| 自启 | 登录时自动启动 / 开机后自动出现在菜单栏。 |
| 通知 | 通知 / 已开启 / 未开启 / 已拒绝 / 去设置 |
| 面板样式 | 状态面板样式 |
| 插件 | 插件 / 内置 / 启用 / 删除 / 恢复默认 |
| 安装 | 从文件夹安装… / 打开插件目录 |
| 插件空态 | 还没有安装插件 / 插件只会改变状态面板的内容，不会执行代码。 |
| 安装失败标题 | 无法安装插件 |
| 插件错误徽标 | 加载失败：{错误码} {原因} |
| 权限行 | 通知 / 登录项 / 全磁盘访问 / 已开启 / 未开启 / 已拒绝 / 未知 / 去设置 |
| 权限说明 | 全磁盘访问用于读取应用残留；不授权时部分残留无法统计。 |
| 关于 | 版本 0.2.0（构建 1）/ 内置 mole：{版本} / 重新查看引导 / 退出 Otter |
| 版权 | Otter · 个人项目 |

### 9.4 首启引导

| 位置 | 文案 |
|---|---|
| 窗口 | 欢迎使用 Otter（620×480） |
| 顶栏 | Otter / 设置向导 / 第 {N} / 3 步 |
| 第 1 步标题 | 抬眼看得到，低头两下清干净 |
| 第 1 步正文 | Otter 常驻菜单栏、不占 Dock。点一下獭图标，面板就在菜单栏下方展开。 |
| 第 1 步要点 | 菜单栏 5 指标（CPU / 内存 / 磁盘 / 上传 / 下载，默认单色，越界才变色）；HUD 面板（5 指标 + TOP3 进程 + 清理 / 卸载快捷入口）；主界面四分区（清理 / 卸载 / 磁盘 / 设置，重活都在这里） |
| 第 1 步按钮 | 继续 / 跳过 |
| 第 2 步标题 | 给 Otter 两个权限 |
| 第 2 步权限行 | 全磁盘访问（扫描缓存、卸载残留、磁盘分析需要读取受保护目录）；系统通知（清理 / 卸载完成后发系统横幅，不用盯着窗口） |
| 第 2 步说明 | 都可在系统设置里随时改；先跳过也能用，只是部分功能受限。 / 提示：在系统设置里勾选 Otter 后返回本窗口，状态会自动刷新。 |
| 第 2 步按钮 | 上一步 / 继续 |
| 第 3 步标题 | 最后两步 |
| 第 3 步自启 | 登录时自动启动 / 重启后菜单栏仍有 Otter，不用手动打开 |
| 第 3 步预设 | 菜单栏显示 / 趋势指标 |
| 第 3 步说明 | 以后随时可以在「设置」里修改。 |
| 第 3 步按钮 | 上一步 / 完成 |
| 重看模式 | 关闭 |
| 登录项失败 | 无法开启自动启动，可在设置里重试 |

### 9.5 通知

见 7.2 文案表（标题/正文/点击行为）。

### 9.6 插件

见 8.7–8.9 文案与错误码。

### 9.7 错误与空态总表

| 码 | 场景 | 文案 |
|---|---|---|
| E01 | 服务未注入 | 数据服务未就绪 / 请重新构建后重试；清理与卸载暂不可用。 |
| E02 | 内置 mole 缺失 | 找不到内置 mole，请重新安装 Otter。 |
| E03 | 扫描超时 | 扫描时间过长，已停止。请重试或换一个目录。 |
| E04 | 用户取消授权 | 已取消授权，没有做任何修改。 |
| E05 | 权限不足 | 没有权限读取「{路径}」。可在系统设置中授予全磁盘访问。 |
| E06 | 写入/废纸篓失败 | 无法移入废纸篓：{原因}。请检查磁盘空间与权限。 |
| E07 | 应用不存在 | 应用已不存在，可能已被移动或删除。 |
| E08 | 受保护 | 该系统应用受保护，无法卸载。 |
| E09 | 部分失败 | 部分项目未能完成（{N} 项），可重试。 |
| E10 | 插件非法 | 插件格式不正确：{P 码原因} |
| E11 | 插件冲突 | 插件 ID 与内置面板冲突。 |
| E12 | 插件写入失败 | 写入插件目录失败，请检查磁盘权限。 |
| E13 | 未知错误 | 出了点问题：{错误描述} / 重试 |
| E14 | 空列表 | 没有找到内容 / 试试更换筛选条件或重新扫描。 |

---

## 10. 与现有代码的接口对照

| 界面/能力 | 现成接口（以源码为准） | 备注 |
|---|---|---|
| 菜单栏标题 | StatusBarController.attributedTitle(ids:metrics:colorByLoad:)；Fmt.percent/rate | 预设 id、阈值色、降级需在此实现 |
| 菜单栏设置 | Prefs.menuBarPreset / showCPU / showMem / showDisk / showUp / showDown / colorByLoad / singleMetric | 无排序键（D1） |
| 指标数据 | SystemMetrics（cpuPercent、memUsedPercent/Bytes/TotalBytes、diskUsedPercent/Bytes/TotalBytes、upBytesPerSec、downBytesPerSec、topProcesses、uptime、coreCount、isReady） | AppState 2s 注入 |
| HUD 数据 | AppState.metrics、AppState.hudVisible | HUD 可见时需 1s（D8） |
| HUD 入口 | AppState.openMainSection(String) / openMainWindow() | 分区字符串用 MainSection.rawValue |
| HUD 尺寸 | HUDWindow 400×520 + NSPanel 行为 | 已符合 |
| 清理 | Services.shared.clean: CleanServicing；CleanPlan/CleanCategory/CleanItem/CleanProgress/CleanResult | preview/run/cancel 完整 |
| 卸载 | Services.shared.uninstall: UninstallServicing；AppItem/UninstallScan/LeftoverItem | trash(items) 不含应用本体（D2） |
| 磁盘 | SystemMetrics.disk* | 分析服务缺失（D3） |
| 设置-自启 | LoginItem.isEnabled / setEnabled | SMAppService |
| 通知 | Notifications.shared.requestAuthorization / post(title:body:) | 点击路由需 delegate（D5） |
| 引导 | UserDefaults「otterOnboarded」；AppDelegate 首次启动占位 | 引导窗口归 dev-shell |
| 插件模型 | HUDPlugin / HUDPluginRow / PluginStore.shared（plugins、activeId、plugin(id:)、reload、install(from:)、remove(id:)） | 字段见 8.3 |
| 插件选择 | Prefs.hudStyle（"n1"/"n8"/插件 id） | 默认 n1 |
| 主界面分区 | MainSection（clean/uninstall/disk/settings）、AppState.selectedSection | 固定四项 |
| 菜单栏自定义顺序 | Prefs.menuBarOrder（CSV） | 自定义预设按此排序（D1 已解决） |
| 暂停采集 | AppState.isPaused / setPaused(Bool) | 右键菜单与 HUD 状态点 |
| 通知开关 | Prefs.notificationsEnabled（SettingsView 扩展，默认 true） | 清理/卸载发通知前判断 |
| 卸载应用本体 | LeftoverItem(kind="app") 置顶，随 trash(items) 移入废纸篓 | D2 已解决 |
| 磁盘分析 | DiskView 内部只读扫描（无独立协议） | D3 已解决；不改 Services.swift |
| 登录自启 | LoginItem.status / isEnabled / setEnabled(Bool)->Bool / statusText / detailText | 失败回滚与提示 |
| 首启引导 | OnboardingController.shared.showIfNeeded()/show(force:)；UserDefaults「otterOnboarded」 | 与 AppDelegate 集成 |
| 通知点击路由 | Notifications.onOpenSection + content.userInfo["section"] | StatusBarController 注入 |
| 验收钩子 | 见附录 B（menubar/plugins/login-status/parse/trash-empty 已实现；缺启动打点/notify） | OTTER_SELFTEST_OUT 可落盘 |

---

## 11. 待拍板与接口缺口

| # | 问题 | 影响 | 建议 |
|---|---|---|---|
| D1 | 自定义指标「排序」：Prefs 无顺序键，Core/Prefs.swift 不在 T3/T4 写范围 | 无法实现拖动排序 | v1 固定顺序 cpu→mem→disk→up→down（本文按此写）；排序列入 v1.1，需授权加 Prefs.customOrder |
| D2 | 卸载「应用本体」：UninstallServicing.trash(items:) 只接收残留，应用本体如何移入废纸篓未定义 | 卸载流程不完整 | 扩展为 trash(app:items:) 或由 mole uninstall 负责并在 UninstallScan 标注；需 dev-data 确认 |
| D3 | 磁盘分析无服务协议 | 磁盘分区只能显示容量 | 新增 DiskServicing（5.4 提案）由 dev-data 实现；否则本轮降级并标注「暂不可用」 |
| D4 | 暂停采集、通知开关、引导重看等需要 Prefs/AppState 新键；App/AppState.swift、Core/Prefs.swift 无 teammate 写权限 | 右键菜单/设置缺项 | Lead 指定归属（建议 T3 授权改 Prefs/AppState，或本轮去掉「暂停采集」） |
| D5 | 通知点击路由需要 UNUserNotificationCenterDelegate，Notifications.swift 在 T3 范围 | 点击通知无法跳转 | T3 实现 delegate + openMainSection 回调注入 |
| D6 | 内置 n1/n8 改为 bundled manifest，但 v1 rows 是单列线性布局，与旧 WebView 网格视觉不同 | 用户观感变化 | 接受线性化（本版不追像素一致）；网格布局列 v1.1 |
| D7 | 验收钩子（OTTER_SELFTEST=menubar/plugins/notify、OTTER_PLUGIN_DIR、启动打点）需改 AppDelegate/Bootstrap | 格式/启动时间难以自动断言 | Lead 统一实现附录 B 钩子（约 40 行） |
| D8 | HUD 1s / 空闲 10s 刷新：AppState 固定 2s，AppState.swift 无 teammate 写权限 | 性能与验收指标 | 与 D4 一并授权；否则按 2s 验收并在 ACCEPTANCE 标注偏差 |
| D9 | 内存 footprint ≤25MB 对 SwiftUI HUD 偏紧（骨架现状未测） | 硬指标可能不达标 | 先按 25MB 验收；若实测平台下限更高，由 Lead 决定放宽到 30MB 并记录理由 |
| D10 | 插件 colors/size 字段：T4 任务描述提到，实际 Plugins.swift 为 width/height/radius 且无 colors | 文档/实现可能漂移 | 以代码为准；colors 列入 v1.1，本版不使用 |

### 11.1 实现核对更新（2026-10-31 15:50）

> 以下状态以当前源码为准；与前表冲突时以本节为准。

**已解决**

| # | 结论 |
|---|---|
| D1 | 已实现 Prefs.menuBarOrder（CSV）+ 自定义顺序渲染 |
| D2 | 卸载应用本体作为 LeftoverItem(kind="app") 置顶，随 trash(items) 移入废纸篓 |
| D3 | 磁盘分析由 DiskView 内部只读扫描实现（未抽协议，行为达标） |
| D4 | AppState.setPaused/isPaused + Prefs.notificationsEnabled（SettingsView 扩展）已具备 |
| D5 | Notifications 实现 UNUserNotificationCenterDelegate 与 onOpenSection 路由 |
| D6 | 接受插件 rows 线性渲染，不追旧 WebView 网格像素 |
| D10 | 以 width/height/radius 为准；无 colors/size 字段 |

**仍在进行**

| # | 状态 | 说明 |
|---|---|---|
| D7 | 部分完成 | menubar/plugins/login-status/parse/trash-empty、OTTER_SELFTEST_OUT 已实现；OTTER_BOOT_LOG 与 notify 钩子未实现（设置页「发送测试」可人工替代通知验证） |
| D8 | 未完成 | AppState 采样仍 2s；HUD 1s 与空闲 10s 未达 SPEC |
| D9 | 待实测 | footprint ≤25MB 尚未测；若平台下限更高由 Lead 决策 |

**新增待办（核对发现）**

| # | 级别 | 问题 | 建议 |
|---|---|---|---|
| D11 | P1 | 宽度降级缺「去图标」中间态：自定义 5 项会只剩 1 项 | 在 L1/L2 之间增加一级，或按 3 个模块估算 |
| D12 | **P0** | 引导第 3 步「登录时自动启动」默认关：OnboardingModel 用 Prefs.launchAtLogin（默认 false）初始化，需求为默认开 | 引导内初始化为 true；无引导环境用 OTTER_LOGIN_OFF 兜底 |
| D13 | **P0** | 用户插件 id 与内置相同时会覆盖内置；且 isBuiltin 判定导致该用户插件不可删除 | 安装/加载时拒绝内置 id（V11） |
| D14 | S3 | 清理/卸载失败只内联提示、未发系统通知 | CleanView/UninstallView 调用 postCleanFailed/postUninstallFailed |
| D15 | S3 | 插件覆盖安装非原子（先删旧目录再复制），失败会丢旧版 | 临时目录 + rename 原子替换 |
| D16 | S4 | 设置/清理/卸载页文案与第 9 章存在差异（实现自创） | 做一次文案回归，以 SPEC 为准或回填 SPEC |
| D17 | 集成 | Resources/plugins/n1.json、n8.json 的行缺少 label 键，而 tester 的 manifest_check.py 要求 metric/style/label 三键齐全 | manifest 补 label（可为 null），或放宽校验器 |
| D18 | 验收 | 缺启动耗时打点；notify 钩子缺失（设置页「发送测试」可人工验证通道） | 补 OTTER_BOOT_LOG；NF-06 暂用外部计时 |
| D19 | 验收 | OTTER_SELFTEST=menubar 的 zero 场景未走 isReady，返回「0% 0%」而非「--」，不能替代未就绪态验收 | 未就绪态用冷启动截图/代码走查验证 |

---

## 12. 版本范围与优先级

### P0（没有就不算能用）

菜单栏常驻 + 4 预设 + 格式规范（F1–F10）；HUD 400×520 + 5 指标 + TOP3 + 三入口 + 空/加载态；清理扫描/预览/勾选/确认/结果/通知（dry-run 验收）；卸载列表/扫描/勾选/确认/废纸篓（守护路径验收）；磁盘容量卡（分析为 P1）；登录自启；通知；首启引导 3 步；设置（菜单栏/通用/权限/关于）；插件 v1 manifest 加载/启用/安装校验/回退；footprint/CPU/启动/包体硬指标。

### P1

磁盘目录分析（D3）；卸载残留分类完整性；暂停采集；火花线；插件删除/打开目录/错误徽标；HUD 1s 刷新；主界面打开时内存 ≤90MB；24h 稳定性；全盘访问引导。

### P2

优化/历史；purge/installer；白名单；treemap；菜单栏插件；插件 JS 沙箱；更新检查；多语言；Touch ID。

---

## 附录 A：格式函数真值表（验收断言用）

**Fmt.percent**

| 输入 | 输出 |
|---|---|
| 0 | 0% |
| 0.4 | 0% |
| 7.2 | 7% |
| 42.6 | 43% |
| 99.6 | 100% |
| 100 | 100% |
| 100.4 | 100%（截断） |
| -1 | 0%（截断） |

**Fmt.rate**

| 输入（B/s） | 输出 |
|---|---|
| 0 | 0B/s |
| 1023 | 1023B/s |
| 1024 | 1K/s |
| 820 × 1024 | 820K/s |
| 1.2 × 1024² | 1.2M/s |
| 1.5 × 1024³ | 1.5G/s |
| 1048575（1MB-1） | 1024K/s（现存缺陷，应显示 1.0M/s；见 BD-19） |

**Fmt.bytes**

| 输入 | 输出 |
|---|---|
| 0 | 0 B |
| 1023 | 1023 B |
| 1024 | 1.0 KB |
| 1536 | 1.5 KB |
| 10240 | 10 KB |
| 512 × 1024² | 512 MB |
| 1.2 × 1024³ | 1.2 GB |
| 16 × 1024³ | 16 GB |

**Fmt.uptime**

| 输入（秒） | 输出 |
|---|---|
| 0 | 0分钟 |
| 59 | 0分钟 |
| 60 | 1分钟 |
| 3599 | 59分钟 |
| 3600 | 1小时0分 |
| 3660 | 1小时1分 |
| 86400 | 1天0小时 |
| 3d14h | 3天14小时 |

## 附录 B：验收钩子（建议实现，见 D7）

| 钩子 | 行为 |
|---|---|
| OTTER_SELFTEST=metrics | 已有：输出一行指标 JSON |
| OTTER_SELFTEST=clean | 已有：dry-run 分类数与总大小 JSON |
| OTTER_SELFTEST=uninstall | 已有：应用数 + 首个应用残留数 JSON |
| OTTER_SELFTEST=menubar（建议） | 用固定合成数据（正常/全 0/全 100/未就绪/1.5G/s）逐预设渲染，输出 JSON 数组：preset、text、width、colors、images、degraded |
| OTTER_SELFTEST=plugins（建议） | 扫描内置+用户插件，输出 [{id,path,valid,errors[]}] |
| OTTER_SELFTEST=notify（建议） | 发送一条示例本地通知（仅验收用），验证通知通道与点击路由 |
| OTTER_PLUGIN_DIR=（建议） | 覆盖用户插件目录（默认 ~/Library/Application Support/Otter/plugins），便于沙箱内用 /tmp 夹具验收插件 |
| OTTER_BOOT_LOG=1（建议） | 启动时输出「[otter] ready {N}ms」（main 到 statusBar.install 完成） |

### 附录 B.1 实际可用钩子（2026-10-31 核对）

| 钩子 | 实际行为 |
|---|---|
| OTTER_SHOW_HUD=1 / OTTER_SHOW_MAIN=1 / OTTER_MAIN_SECTION=clean|uninstall|disk|settings | 启动 1s 后打开对应窗口 |
| OTTER_NO_ONBOARD=1 | 跳过首启引导（验收常用） |
| OTTER_LOGIN_OFF=1 | 启动时关闭登录项（避免开发环境污染） |
| OTTER_SELFTEST=metrics / clean / uninstall / parse / trash-empty | Bootstrap 模式；stdout 打印一行 JSON；OTTER_SELFTEST_OUT 可同时落盘 |
| OTTER_SELFTEST=menubar | MenuBarFormat.selfTestJSON：字段 dual / zero / full / net / reordered / empty（纯文本断言，不含宽度/颜色） |
| OTTER_SELFTEST=plugins | PluginStore.selfTestJSON：校验 OTTER_PLUGIN_DIR 下 *.json，输出 valid/rejected（仅解码与 id/rows 非空，不做完整 validate） |
| OTTER_SELFTEST=login-status | 输出 {"mode":"login-status","enabled":true|false} |
| OTTER_SELFTEST_INPUT | parse 模式的输入文件路径 |
| OTTER_SELFTEST_RAW | clean 模式把 dry-run 原始文本落盘 |
| OTTER_PLUGIN_DIR | 仅 plugins 模式校验目录用；**不是**加载目录覆盖 |
| 未实现 | OTTER_BOOT_LOG（启动打点）、notify（通知通道用设置页「发送测试」人工验证） |

## 附录 C：术语

| 术语 | 含义 |
|---|---|
| 状态面板 / HUD | 点击菜单栏弹出的 400×520 浮层 |
| 主界面 | 960×660 的四分区窗口 |
| 预设 | 菜单栏的 4 种显示方案 |
| 插件 | 声明式 HUD manifest（v1 仅 HUD） |
| 残留 | 应用卸载后留在 ~/Library 等处的文件 |
| 收尾确认 | 唯一允许的模态弹窗，用于清理/卸载前确认 |
