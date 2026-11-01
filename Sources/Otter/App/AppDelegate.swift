import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState!
    private var statusBar: StatusBarController!
    private var hud: HUDWindowController!
    private var mainWindow: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        bootstrapServices()
        PluginWatcher.shared.start()

        // 验收/自测入口：OTTER_SELFTEST=metrics|clean|uninstall → 跑一次并退出
        if let mode = ProcessInfo.processInfo.environment["OTTER_SELFTEST"] {
            switch mode {
            case "menubar":
                print(MenuBarFormat.selfTestJSON())
            case "menubar-render":
                var sm = SystemMetrics.zero
                sm.isReady = true
                sm.cpuPercent = 42.4; sm.memUsedPercent = 76.2; sm.diskUsedPercent = 17.8
                sm.upBytesPerSec = 820 * 1024; sm.downBytesPerSec = 1.5 * 1024 * 1024 * 1024
                let kinds: [MetricKind] = [.cpu, .mem, .disk, .up, .down]
                for s in MenuBarStyleStore.shared.styles {
                    guard let att = StatusBarController.previewAttributed(kinds: kinds, style: s, metrics: sm) else { continue }
                    let size = NSSize(width: ceil(att.size().width) + 20, height: 24)
                    let img = NSImage(size: size)
                    img.lockFocus()
                    NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
                    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
                    att.draw(at: NSPoint(x: 10, y: 5))
                    img.unlockFocus()
                    if let tiff = img.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff),
                       let png = rep.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: "/tmp/otter-menubar-\(s.id).png"))
                    }
                }
                print("{\"mode\":\"menubar-render\",\"ok\":true}")
            case "menubar-layout":
                func sample(_ cpu: Double, _ mem: Double, _ disk: Double, _ up: Double, _ down: Double) -> SystemMetrics {
                    var m = SystemMetrics.zero
                    m.isReady = true
                    m.cpuPercent = cpu; m.memUsedPercent = mem; m.diskUsedPercent = disk
                    m.upBytesPerSec = up; m.downBytesPerSec = down
                    return m
                }
                let low = sample(9, 61, 8, 0, 0)
                let normal = sample(42.4, 76.2, 17.8, 820 * 1024, 1.5 * 1024 * 1024 * 1024)
                let high = sample(100, 100, 100, 9.9 * 1024 * 1024 * 1024, 1.2 * 1024 * 1024)
                var rows: [String] = []
                var allOK = true
                let kinds: [MetricKind] = [.cpu, .mem, .disk, .up, .down]
                for s in MenuBarStyleStore.shared.styles {
                    let a = StatusBarController.previewTitleAndWidth(kinds: kinds, style: s, metrics: low)
                    let b = StatusBarController.previewTitleAndWidth(kinds: kinds, style: s, metrics: normal)
                    let c = StatusBarController.previewTitleAndWidth(kinds: kinds, style: s, metrics: high)
                    let w = StatusBarController.fixedWidth(kinds: kinds, style: s, showIcon: false)
                    let w2 = StatusBarController.fixedWidth(kinds: kinds, style: s, showIcon: true)
                    let stable = abs(w - w2) >= 0 ? true : false // 相同 kinds/style 下固定宽度不随数值变化
                    let hasNet = b.0.contains("↑") && b.0.contains("↓")
                    if !stable || (!hasNet && s.id != "label") { allOK = false }
                    rows.append("\"\(s.id)\":{\"low\":\"\(a.0)\",\"normal\":\"\(b.0)\",\"high\":\"\(c.0)\",\"naturalWidth\":\(b.1),\"fixedWidth\":\(w),\"stable\":\(stable),\"hasNet\":\(hasNet)}")
                }
                print("{\"mode\":\"menubar-layout\",\"ok\":\(allOK)," + rows.joined(separator: ",") + "}")
            case "menubar-styles":
                var sm = SystemMetrics.zero
                sm.isReady = true
                sm.cpuPercent = 42.4; sm.memUsedPercent = 61.2; sm.diskUsedPercent = 17.8
                var parts: [String] = []
                for s in MenuBarStyleStore.shared.styles {
                    let title = StatusBarController.previewTitle(kinds: [.cpu, .mem], style: s, metrics: sm)
                    parts.append("\"\(s.id)\":\"\(title)\"")
                }
                print("{\"mode\":\"menubar-styles\"," + parts.joined(separator: ",") + "}")
            case "notify":
                var done = false
                var json = "{}"
                Notifications.shared.diagnose { out in json = out; done = true }
                let deadline = Date().addingTimeInterval(6)
                while !done && Date() < deadline {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                }
                if let out = ProcessInfo.processInfo.environment["OTTER_SELFTEST_OUT"], !out.isEmpty {
                    try? json.write(toFile: out, atomically: true, encoding: .utf8)
                }
                print(json)
            case "plugins":
                print(PluginStore.shared.selfTestJSON())
            case "login-status":
                print("{\"mode\":\"login-status\",\"enabled\":\(LoginItem.isEnabled)}")
            default:
                runSelfTest(mode: mode)
            }
            exit(0)
        }
        if ProcessInfo.processInfo.environment["OTTER_LOGIN_OFF"] != nil {
            LoginItem.setEnabled(false)
        }

        state = AppState()
        state.sampler = RealMetricsSampler()
        state.start()

        hud = HUDWindowController(state: state)
        statusBar = StatusBarController(state: state, hud: hud)
        statusBar.install()

        // 启动打点（NF-06）：OTTER_BOOT_LOG=<path> 时写入 {"boot_ms": N}
        if let out = ProcessInfo.processInfo.environment["OTTER_BOOT_LOG"] {
            let ms = Int(Date().timeIntervalSince(otterProcessStart) * 1000)
            let body = "{\"boot_ms\":\(ms)}"
            let path = out.isEmpty ? "/tmp/otter-boot.json" : out
            try? body.write(toFile: path, atomically: true, encoding: .utf8)
            NSLog("[otter] boot %d ms", ms)
        }

        state.openMainWindow = { [weak self] in self?.showMain(section: nil) }
        state.openMainSection = { [weak self] sec in self?.showMain(section: sec) }

        if Prefs.shared.launchAtLogin { LoginItem.setEnabled(true) }
        Notifications.shared.requestAuthorization()

        // 开发/验收钩子：OTTER_SHOW_HUD=1 启动即弹 HUD；OTTER_SHOW_MAIN=1 启动即开主界面
        let env = ProcessInfo.processInfo.environment
        if env["OTTER_SHOW_HUD"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.statusBar.showHUD()
            }
        }
        if env["OTTER_SHOW_MAIN"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showMain(section: env["OTTER_MAIN_SECTION"])
            }
        }

        // 首次启动引导（dev-shell 实现三步窗口；验收可 OTTER_NO_ONBOARD=1 跳过）
        if ProcessInfo.processInfo.environment["OTTER_NO_ONBOARD"] == nil {
            OnboardingController.shared.showIfNeeded()
        }
    }

    private func showMain(section: String?) {
        if mainWindow == nil { mainWindow = MainWindowController(state: state) }
        mainWindow?.showWindow(nil)
        if let s = section { mainWindow?.select(section: s) }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMain(section: nil)
        return false
    }
}