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
    @objc private func openAbout() {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let credits = NSAttributedString(
            string: "海獭图标：马蒂斯剪纸风格（Otter 原创绘制）\n清理引擎：mole\n本地运行 · 无网络请求",
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

        // 菜单栏始终带一枚獭图标，指标文字跟在后面（和引导里「点一下獭图标」一致）
        button.image = MenuBarGlyph.brandTemplate()
        button.imagePosition = .imageLeading
        item.length = NSStatusItem.variableLength

        let trend: MetricKind? = preset == .single ? kinds.first : nil
        if let title = Self.fittedTitle(kinds: kinds, trend: trend, metrics: m, labelColor: labelColor, colorByLoad: Prefs.shared.colorByLoad) {
            button.attributedTitle = title
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
                           colorByLoad: Prefs.shared.colorByLoad) ?? NSAttributedString(string: "")
    }

    /// 按预算逐级降级，返回第一条放得下的标题
    static func fittedTitle(kinds: [MetricKind], trend: MetricKind?, metrics m: SystemMetrics, labelColor: NSColor, colorByLoad: Bool) -> NSAttributedString? {
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
                                      colorByLoad: colorByLoad)
            if att.size().width + 2 <= ShellPrefs.menuBarWidthBudget { return att }
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
                                   colorByLoad: Bool) -> NSAttributedString {
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
            if i > 0 { text(" ", labelColor) }
            if let sym = MenuBarGlyph.symbol(kind.symbol, pointSize: 11, color: labelColor) {
                out.append(MenuBarGlyph.attachment(sym, font: valueFont))
            }
            let color = ShellPrefs.menuBarColor(load: kind.load(m), colorByLoad: colorByLoad)
            text(kind.display(m), color)

            if let t = trend, kind == t {
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
