import AppKit
import Combine

/// 菜单栏控制器：
///   · 4 预设（极简 / 双指标 / 单指标+趋势 / 自定义）；
///   · 格式规范：百分比不补零、速率带单位、默认单色、仅阈值色（≥85 红 / ≥60 黄，需开关）、
///     SF Symbol 着色图随深浅色反色；
///   · 宽度预算 120pt，超限自动降级：去趋势 → 只留主指标 → 只留图标；
///   · 数据未就绪显示 "--" 占位；
///   · 左键开 HUD，右键菜单（面板 / 主界面 / 设置 / 暂停采集 / 欢迎引导 / 关于 / 退出）。
final class StatusBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let state: AppState
    private let hud: HUDWindowController
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastSignature = ""

    init(state: AppState, hud: HUDWindowController) {
        self.state = state
        self.hud = hud
        super.init()
    }

    func install() {
        guard let button = item.button else { return }
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(onClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Otter · 系统状态"

        // 趋势历史：每次采样喂给 ShellState（HUD 火花线也读它）
        state.$metrics
            .receive(on: RunLoop.main)
            .sink { [weak self] m in
                ShellState.shared.ingest(m)
                self?.refresh(force: false)
            }
            .store(in: &cancellables)

        // 设置页 / 引导改完偏好后立即刷新
        NotificationCenter.default.addObserver(forName: ShellPrefs.changedNotification,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            self?.refresh(force: true)
        }

        // 点按系统通知 → 打开主界面对应分区
        Notifications.shared.onOpenSection = { [weak self] section in
            guard let self = self else { return }
            if let section = section {
                self.state.openMainSection?(section)
            } else {
                self.state.openMainWindow?()
            }
        }

        refresh(force: true)

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.refresh(force: false) }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - 点击

    @objc private func onClick() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showMenu()
        } else {
            hud.toggle(relativeTo: item.button)
        }
        refresh(force: true)
    }

    /// 开发/验收钩子：AppDelegate 的 OTTER_SHOW_HUD=1 会调用
    func showHUD() { hud.show(relativeTo: item.button) }

    // MARK: - 右键菜单

    private func showMenu() {
        guard let button = item.button else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false

        addItem(menu, "打开面板", #selector(openHUD), "")
        addItem(menu, "主界面", #selector(openMain), "")
        addItem(menu, "设置", #selector(openSettings), "")
        menu.addItem(.separator())

        let pause = NSMenuItem(title: state.isPaused ? "恢复采集" : "暂停采集",
                               action: #selector(togglePause),
                               keyEquivalent: "")
        pause.target = self
        pause.state = state.isPaused ? .on : .off
        menu.addItem(pause)

        menu.addItem(.separator())
        addItem(menu, "欢迎引导…", #selector(openOnboarding), "")
        addItem(menu, "检查更新…", #selector(checkUpdates), "")
        addItem(menu, "关于 Otter", #selector(openAbout), "")
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 Otter", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
        mi.target = self
        menu.addItem(mi)
    }

    @objc private func openHUD() { hud.show(relativeTo: item.button) }
    @objc private func openMain() { state.openMainWindow?() }
    @objc private func openSettings() { state.openMainSection?("settings") }
    @objc private func togglePause() {
        state.setPaused(!state.isPaused)
        refresh(force: true)
    }
    @objc private func openOnboarding() { OnboardingController.shared.show(force: true) }
    @objc private func checkUpdates() {
        let feed = Prefs.shared.updateFeedURL
        guard !feed.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "尚未配置更新源"
            alert.informativeText = "请在「设置 → 更新」里填入 GitHub Releases API 或自定义 JSON 地址。"
            alert.addButton(withTitle: "去设置")
            alert.addButton(withTitle: "取消")
            if alert.runModal() == .alertFirstButtonReturn { openSettings() }
            return
        }
        UpdateService.check(feedURLString: feed) { result in
            DispatchQueue.main.async {
                let alert = NSAlert()
                switch result {
                case .upToDate(let current):
                    alert.messageText = "已是最新版本"
                    alert.informativeText = "当前 v\(current)"
                    alert.addButton(withTitle: "好")
                    alert.runModal()
                case .available(let info):
                    alert.messageText = "发现新版本 v\(info.version)"
                    alert.informativeText = info.notes.isEmpty ? "在设置 → 更新中下载 DMG。" : info.notes
                    alert.addButton(withTitle: "打开设置")
                    alert.addButton(withTitle: "稍后")
                    if alert.runModal() == .alertFirstButtonReturn { self.openSettings() }
                case .failure(let message):
                    alert.messageText = "检查更新失败"
                    alert.informativeText = message
                    alert.addButton(withTitle: "好")
                    alert.runModal()
                }
            }
        }
    }

    @objc private func openAbout() {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let credits = NSAttributedString(
            string: "海獭图标：马蒂斯剪纸风格（Otter 原创绘制）\n原生清理引擎\n本地运行 · 无网络请求",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ])
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Otter",
            .applicationVersion: "v" + v,
            .version: "",
            .credits: credits
        ])
    }
    @objc private func quit() { NSApp.terminate(nil) }
    // MARK: - 渲染

    /// force=false 时按「指标时间戳 + 外观 + 偏好 + 暂停」签名去重，避免每秒重绘
    func refresh(force: Bool = false) {
        guard let button = item.button else { return }
        let m = state.metrics
        let preset = MenuBarPreset.current()
        let appearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua
        let signature = [
            preset.rawValue,
            String(m.timestamp.timeIntervalSince1970),
            String(m.isReady),
            appearance.rawValue,
            String(state.isPaused),
            String(Prefs.shared.menuBarShowIcon),
            Prefs.shared.menuBarStyle,
            Self.prefsSignature(),
        ].joined(separator: "|")
        guard force || signature != lastSignature else { return }
        lastSignature = signature

        let labelColor = MenuBarGlyph.currentLabelColor()
        button.toolTip = tooltip(m)

        let kinds = Self.kinds(for: preset)
        if kinds.isEmpty {
            // 极简 / 自定义未勾选任何指标 → 只留獭图标
            applyIconOnly(button)
            return
        }

        // 獭图标可关（默认关）；关闭后只显示指标文字。
        button.image = Prefs.shared.menuBarShowIcon ? MenuBarGlyph.brandTemplate() : nil
        button.imagePosition = .imageLeading
        item.length = NSStatusItem.variableLength

        let trend: MetricKind? = preset == .single ? kinds.first : nil
        let menuBarStyle = MenuBarStyleStore.shared.style
        let menuBarShowIcon = Prefs.shared.menuBarShowIcon
        let target = Self.fixedWidth(kinds: kinds, style: menuBarStyle, showIcon: menuBarShowIcon)
        if let title = Self.fittedTitle(kinds: kinds, trend: trend, metrics: m, labelColor: labelColor, colorByLoad: Prefs.shared.colorByLoad, budget: target) {
            let style = menuBarStyle
            let showIcon = menuBarShowIcon
            let iconWidth: CGFloat = showIcon ? 22 : 0
            let pad = max(0, target - title.size().width - iconWidth - 14)
            let out = NSMutableAttributedString(attributedString: title)
            if pad > 0.5 {
                let spacer = NSImage(size: NSSize(width: pad, height: 1))
                out.append(MenuBarGlyph.attachment(spacer, font: NSFont.menuBarFont(ofSize: 0)))
            }
            button.attributedTitle = out
            item.length = target
        } else {
            // 超出宽度预算且降级到底 → 图标
            applyIconOnly(button)
        }
    }

    private func applyIconOnly(_ button: NSStatusBarButton) {
        item.length = NSStatusItem.squareLength
        button.attributedTitle = NSAttributedString(string: "")
        button.image = MenuBarGlyph.brandTemplate()
    }

    /// 当前预设要显示的指标（自定义会同时应用勾选与排序）
    static func kinds(for preset: MenuBarPreset) -> [MetricKind] {
        switch preset {
        case .minimal:
            return []
        case .dual:
            return [.cpu, .mem]
        case .single:
            return [MetricKind.parse(Prefs.shared.singleMetric) ?? .cpu]
        case .custom:
            let enabled: [MetricKind: Bool] = [
                .cpu: Prefs.shared.showCPU,
                .mem: Prefs.shared.showMem,
                .disk: Prefs.shared.showDisk,
                .up: Prefs.shared.showUp,
                .down: Prefs.shared.showDown,
            ]
            let order = Prefs.shared.menuBarOrder.compactMap { MetricKind.parse($0) }
            let picked = order.filter { enabled[$0] == true }
            return picked
        }
    }

    static func prefsSignature() -> String {
        [
            String(Prefs.shared.colorByLoad),
            String(Prefs.shared.singleMetric),
            String(Prefs.shared.showCPU), String(Prefs.shared.showMem),
            String(Prefs.shared.showDisk), String(Prefs.shared.showUp),
            String(Prefs.shared.showDown),
            Prefs.shared.menuBarOrder.joined(separator: ","),
        ].joined(separator: ",")
    }

    /// 验收辅助：按当前偏好生成某个预设的菜单栏标题（趋势/降级与线上一致）。
    /// 浅色/深色取决于 NSApp.effectiveAppearance，供 offscreen 渲染断言用。
    static func previewTitle(preset: MenuBarPreset, metrics: SystemMetrics) -> NSAttributedString {
        let kinds = kinds(for: preset)
        guard !kinds.isEmpty else { return NSAttributedString(string: "") }
        let trend: MetricKind? = preset == .single ? kinds.first : nil
        return fittedTitle(kinds: kinds,
                           trend: trend,
                           metrics: metrics,
                           labelColor: MenuBarGlyph.currentLabelColor(),
                           colorByLoad: Prefs.shared.colorByLoad,
                           style: MenuBarStyleStore.shared.style) ?? NSAttributedString(string: "")
    }

    /// 固定菜单栏宽度：按「所有已启用指标 + 最坏情况数值」测算，数值变化/个别指标被裁都不会改宽度。
    static func fixedWidth(kinds: [MetricKind], style: MenuBarStyle, showIcon: Bool) -> CGFloat {
        // 取常见极值的最大标题宽度：0、几十%、100% 与 0B/s、数百K、G 级速率。
        let samples: [SystemMetrics] = [
            sampleMetrics(cpu: 9, mem: 9, disk: 9, up: 0, down: 0),
            sampleMetrics(cpu: 42, mem: 76, disk: 18, up: 820 * 1024, down: 1.5 * 1024 * 1024 * 1024),
            sampleMetrics(cpu: 100, mem: 100, disk: 100, up: 9.9 * 1024 * 1024 * 1024, down: 1.2 * 1024 * 1024),
        ]
        let widths = samples.map { m in
            buildTitle(kinds: kinds,
                       trend: nil,
                       metrics: m,
                       labelColor: MenuBarGlyph.currentLabelColor(),
                       colorByLoad: false,
                       style: style).size().width
        }
        return max(44, ceil((widths.max() ?? 0) + (showIcon ? 22 : 0) + 12))
    }

    private static func sampleMetrics(cpu: Double, mem: Double, disk: Double, up: Double, down: Double) -> SystemMetrics {
        var m = SystemMetrics.zero
        m.isReady = true
        m.cpuPercent = cpu; m.memUsedPercent = mem; m.diskUsedPercent = disk
        m.upBytesPerSec = up; m.downBytesPerSec = down
        return m
    }

    /// 验收辅助：按指定样式生成标题（自测用，不影响线上）。
    static func previewTitle(kinds: [MetricKind], style: MenuBarStyle, metrics: SystemMetrics) -> String {
        previewTitleAndWidth(kinds: kinds, style: style, metrics: metrics).0
    }

    /// 自测用：返回实际属性标题（含图标附件）。
    static func previewAttributed(kinds: [MetricKind], style: MenuBarStyle, metrics: SystemMetrics) -> NSAttributedString? {
        let budget = fixedWidth(kinds: kinds, style: style, showIcon: false)
        return fittedTitle(kinds: kinds,
                           trend: nil,
                           metrics: metrics,
                           labelColor: MenuBarGlyph.currentLabelColor(),
                           colorByLoad: false,
                           style: style,
                           budget: budget)
    }

    /// 自测用：返回标题与像素宽度，验证固定宽度。
    static func previewTitleAndWidth(kinds: [MetricKind], style: MenuBarStyle, metrics: SystemMetrics) -> (String, CGFloat) {
        let budget = fixedWidth(kinds: kinds, style: style, showIcon: false)
        guard let att = fittedTitle(kinds: kinds,
                                    trend: nil,
                                    metrics: metrics,
                                    labelColor: MenuBarGlyph.currentLabelColor(),
                                    colorByLoad: false,
                                    style: style,
                                    budget: budget) else { return ("", 0) }
        return (att.string, att.size().width)
    }

    /// 按预算逐级降级，返回第一条放得下的标题
    static func fittedTitle(kinds: [MetricKind], trend: MetricKind?, metrics m: SystemMetrics, labelColor: NSColor, colorByLoad: Bool, style: MenuBarStyle? = nil, budget: CGFloat = ShellPrefs.menuBarWidthBudget) -> NSAttributedString? {
        var candidates: [(kinds: [MetricKind], withTrend: Bool)] = []
        if trend != nil {
            candidates.append((kinds, true))
            candidates.append((kinds, false))
        } else {
            // 自定义多指标：从完整列表开始逐个丢弃末尾的次要指标，尽量多留
            var remaining = kinds
            while remaining.count > 1 {
                candidates.append((remaining, false))
                remaining.removeLast()
            }
            candidates.append((remaining, false))
        }
        for c in candidates {
            let att = Self.buildTitle(kinds: c.kinds,
                                      trend: c.withTrend ? trend : nil,
                                      metrics: m,
                                      labelColor: labelColor,
                                      colorByLoad: colorByLoad,
                                      style: style ?? MenuBarStyleStore.shared.style)
            if att.size().width + 2 <= budget { return att }
        }
        return nil
    }

    // MARK: - 菜单栏标题（格式规范落到这一个函数）

    /// 兼容旧签名（tester/devtest 可能直接断言）
    static func attributedTitle(ids: [String], metrics m: SystemMetrics, colorByLoad: Bool) -> NSAttributedString {
        let kinds = ids.compactMap { MetricKind.parse($0) }
        return buildTitle(kinds: kinds,
                          trend: nil,
                          metrics: m,
                          labelColor: MenuBarGlyph.currentLabelColor(),
                          colorByLoad: colorByLoad)
    }

    private static func buildTitle(kinds: [MetricKind],
                                   trend: MetricKind?,
                                   metrics m: SystemMetrics,
                                   labelColor: NSColor,
                                   colorByLoad: Bool,
                                   style: MenuBarStyle = MenuBarStyleStore.shared.style) -> NSAttributedString {
        let baseFont = NSFont.menuBarFont(ofSize: 0)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: baseFont.pointSize, weight: .regular)
        let out = NSMutableAttributedString()

        func text(_ s: String, _ color: NSColor) {
            out.append(NSAttributedString(string: s, attributes: [
                .font: valueFont,
                .foregroundColor: color,
            ]))
        }

        for (i, kind) in kinds.enumerated() {
            if i > 0 { text(style.separator, labelColor) }
            if style.showIcons, let sym = MenuBarGlyph.symbol(kind.symbol, pointSize: 11, color: labelColor) {
                out.append(MenuBarGlyph.attachment(sym, font: valueFont))
            }
            if style.showLabels {
                let labelFont = NSFont.menuBarFont(ofSize: baseFont.pointSize - 1)
                out.append(NSAttributedString(string: kind.title + " ", attributes: [
                    .font: labelFont,
                    .foregroundColor: labelColor.withAlphaComponent(0.75),
                ]))
            }
            let color = ShellPrefs.menuBarColor(load: kind.load(m), colorByLoad: colorByLoad)
            text(MenuBarFormat.menuBarValue(kind, m), color)

            let showTrend = style.showTrend && kinds.count == 1
            if showTrend {
                text(" ", labelColor)
                let raw = ShellState.shared.historyValues(kind, count: 8)
                let normalized: [Double]
                if kind.isRate {
                    let peak = raw.max() ?? 0
                    normalized = peak > 0 ? raw.map { $0 / peak } : raw.map { _ in 0 }
                } else {
                    normalized = raw.map { min(max($0 / 100, 0), 1) }
                }
                out.append(MenuBarGlyph.attachment(MenuBarGlyph.trend(normalized, color: labelColor), font: valueFont))
            }
        }
        return out
    }

    // MARK: - tooltip

    private func tooltip(_ m: SystemMetrics) -> String {
        let head = state.isPaused ? "采集已暂停 · " : ""
        guard m.isReady else { return head + "Otter · 正在读取系统指标…" }
        let parts = MetricKind.allCases.map { "\($0.title) \($0.display(m))" }
        var detail = parts.joined(separator: " · ")
        detail += " · 已开机 \(Fmt.uptime(m.uptime))"
        if m.coreCount > 0 { detail += " · \(m.coreCount) 核" }
        return head + detail
    }
}