import AppKit

final class StatusBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let state: AppState
    private let hud: HUDWindowController
    private var timer: Timer?

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
        refresh()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func onClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
            return
        }
        hud.toggle(relativeTo: item.button)
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "打开面板", action: #selector(openHUD), keyEquivalent: "").target = self
        menu.addItem(withTitle: "主界面", action: #selector(openMain), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置", action: #selector(openSettings), keyEquivalent: "").target = self
        menu.addItem(withTitle: "退出 Otter", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func openHUD() { hud.show(relativeTo: item.button) }

    /// 开发/验收用：外部触发弹 HUD
    func showHUD() { hud.show(relativeTo: item.button) }
    @objc private func openMain() { state.openMainWindow?() }
    @objc private func openSettings() { state.openMainSection?("settings") }
    @objc private func quit() { NSApp.terminate(nil) }

    func refresh() {
        guard let button = item.button else { return }
        let m = state.metrics
        let preset = Prefs.shared.menuBarPreset

        if preset == "minimal" {
            item.length = NSStatusItem.squareLength
            button.attributedTitle = NSAttributedString(string: "")
            button.image = Self.brandTemplateImage()
            return
        }
        button.image = nil
        item.length = NSStatusItem.variableLength

        var ids: [String] = []
        switch preset {
        case "single": ids = [Prefs.shared.singleMetric]
        case "custom":
            if Prefs.shared.showCPU { ids.append("cpu") }
            if Prefs.shared.showMem { ids.append("mem") }
            if Prefs.shared.showDisk { ids.append("disk") }
            if Prefs.shared.showUp { ids.append("up") }
            if Prefs.shared.showDown { ids.append("down") }
        default: ids = ["cpu", "mem"]
        }
        button.attributedTitle = Self.attributedTitle(ids: ids, metrics: m, colorByLoad: Prefs.shared.colorByLoad)
    }

    // MARK: - 菜单栏标题（格式规范：不补零 / 速率带单位 / 默认单色 / 越界才着色）

    private static func brandTemplateImage() -> NSImage? {
        let img = NSImage(systemSymbolName: "water.waves", accessibilityDescription: "Otter")
            ?? NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Otter")
        img?.isTemplate = true
        return img
    }

    private static func symbolAttachment(_ name: String) -> NSAttributedString {
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return NSAttributedString(string: "")
        }
        img.isTemplate = true
        let att = NSTextAttachment()
        att.image = img
        att.bounds = CGRect(x: 0, y: -1.5, width: 11, height: 11)
        return NSAttributedString(attachment: att)
    }

    static func attributedTitle(ids: [String], metrics m: SystemMetrics, colorByLoad: Bool) -> NSAttributedString {
        let font = NSFont.menuBarFont(ofSize: 0)
        let out = NSMutableAttributedString()
        let labelColor = NSColor.labelColor

        func color(for v: Double) -> NSColor {
            guard colorByLoad else { return labelColor }
            if v >= 85 { return .systemRed }
            if v >= 60 { return .systemYellow }
            return labelColor
        }

        for (i, id) in ids.enumerated() {
            if i > 0 {
                out.append(NSAttributedString(string: " ", attributes: [.font: font, .foregroundColor: labelColor]))
            }
            let value: String
            let sym: String
            let load: Double
            switch id {
            case "mem": value = Fmt.percent(m.memUsedPercent); sym = "memorychip"; load = m.memUsedPercent
            case "disk": value = Fmt.percent(m.diskUsedPercent); sym = "internaldrive"; load = m.diskUsedPercent
            case "up": value = Fmt.rate(m.upBytesPerSec); sym = "arrow.up"; load = 0
            case "down": value = Fmt.rate(m.downBytesPerSec); sym = "arrow.down"; load = 0
            default: value = Fmt.percent(m.cpuPercent); sym = "cpu"; load = m.cpuPercent
            }
            let c = color(for: load)
            out.append(symbolAttachment(sym))
            out.append(NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: c]))
        }
        return out
    }
}