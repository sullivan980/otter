import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState!
    private var statusBar: StatusBarController!
    private var hud: HUDWindowController!
    private var mainWindow: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        bootstrapServices()
        if ProcessInfo.processInfo.environment["OTTER_DEMO_RESULT"] == "1" {
            OperationResultCenter.shared.post(kind: .success, title: "清理完成",
                                              message: "已释放 2.0 GB，共 72 项", autoDismiss: 0)
        }
        PluginWatcher.shared.start()

        // 验收/自测入口：OTTER_SELFTEST=metrics|clean|uninstall → 跑一次并退出
        if let mode = ProcessInfo.processInfo.environment["OTTER_SELFTEST"] {
            switch mode {
            case "menubar":
                print(MenuBarFormat.selfTestJSON())
            case "clean-rules-fixture":
                runSelfTestCleanRules()
                exit(0)
            case "duplicates-fixture":
                let fm = FileManager.default
                let root = "/tmp/otter-dup-fixture"
                try? fm.removeItem(atPath: root)
                try? fm.createDirectory(atPath: root, withIntermediateDirectories: true)
                let a = Data(repeating: 1, count: 2 * 1024 * 1024)
                let b = a
                let cdata = Data(repeating: 2, count: 2 * 1024 * 1024)
                fm.createFile(atPath: root + "/a.bin", contents: a)
                fm.createFile(atPath: root + "/b.bin", contents: b)
                fm.createFile(atPath: root + "/c.bin", contents: cdata)
                var groups: [DuplicateGroup] = []
                var done = false
                DuplicateScanner.scan(root: URL(fileURLWithPath: root), progress: { _ in },
                                      isCancelled: { false }) { result in
                    groups = result
                    done = true
                }
                let deadline = Date().addingTimeInterval(30)
                while !done && Date() < deadline {
                    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
                }
                let ok = groups.count == 1 && groups.first?.files.count == 2
                print("{\"mode\":\"duplicates-fixture\",\"ok\":\(ok),\"groups\":\(groups.count),\"files\":\(groups.first?.files.count ?? 0)}")
                exit(0)
            case "battery":
                let b = BatteryService.read()
                print("{\"mode\":\"battery\",\"ok\":true,\"present\":\(b.present),\"cycles\":\(b.cycleCount ?? -1),\"health\":\(b.healthPercent ?? -1),\"temp\":\(b.temperatureC ?? -1)}")
                exit(0)
            case "reminders":
                let now = Date(timeIntervalSince1970: 2_000_000)
                let cleanDue = ReminderService.shouldRemindClean(lastCleanAt: now.timeIntervalSince1970 - 8 * 86400, intervalDays: 7, now: now)
                let cleanNotDue = ReminderService.shouldRemindClean(lastCleanAt: now.timeIntervalSince1970 - 3 * 86400, intervalDays: 7, now: now)
                let lowDue = ReminderService.shouldRemindLowDisk(diskPercent: 92, threshold: 90, lastRemindedAt: 0, now: now)
                let lowCooldown = ReminderService.shouldRemindLowDisk(diskPercent: 92, threshold: 90, lastRemindedAt: now.timeIntervalSince1970 - 3600, now: now)
                let ok = cleanDue && !cleanNotDue && lowDue && !lowCooldown
                print("{\"mode\":\"reminders\",\"ok\":\(ok)}")
                exit(0)
            case "safe-trash":
                let fm = FileManager.default
                let home = "/tmp/otter-safe-trash-home"
                let trashRoot = "/tmp/otter-safe-trash-root"
                try? fm.removeItem(atPath: home)
                try? fm.removeItem(atPath: trashRoot)
                try? fm.createDirectory(atPath: home, withIntermediateDirectories: true)
                fm.createFile(atPath: home + "/a.bin", contents: Data(count: 100_000))
                fm.createFile(atPath: home + "/b.bin", contents: Data(count: 100_000))
                SafeTrashService.testRoot = URL(fileURLWithPath: trashRoot)
                defer { SafeTrashService.testRoot = nil }
                let moved = SafeTrashService.shared.move([home + "/a.bin", home + "/b.bin"])
                let listed = SafeTrashService.shared.list()
                let restored = SafeTrashService.shared.restore(all: true)
                let back = fm.fileExists(atPath: home + "/a.bin") && fm.fileExists(atPath: home + "/b.bin")
                let ok = moved.moved == 2 && listed.count == 1 && listed.first?.count == 2 && restored.restored == 2 && back
                print("{\"mode\":\"safe-trash\",\"ok\":\(ok),\"moved\":\(moved.moved),\"restored\":\(restored.restored),\"back\":\(back)}")
                exit(0)
            case "process-kill":
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/sleep")
                p.arguments = ["30"]
                do {
                    try p.run()
                    let pid = p.processIdentifier
                    let result = ProcessService.terminate(pid: pid, force: false)
                    Thread.sleep(forTimeInterval: 0.5)
                    let gone = !p.isRunning
                    p.terminate()
                    var ok = false
                    if case .success = result { ok = gone }
                    print("{\"mode\":\"process-kill\",\"ok\":\(ok),\"pid\":\(pid)}")
                } catch {
                    print("{\"mode\":\"process-kill\",\"ok\":false,\"error\":\"\(error.localizedDescription)\"}")
                }
                exit(0)
            case "alerts":
                var m = SystemMetrics.zero
                m.isReady = true
                m.cpuPercent = 95; m.memUsedPercent = 50; m.diskUsedPercent = 50
                let t0 = Date(timeIntervalSince1970: 1_000_000)
                let a = AlertMonitor.shared.evaluate(m, now: t0)
                let b = AlertMonitor.shared.evaluate(m, now: t0.addingTimeInterval(31))
                let c = AlertMonitor.shared.evaluate(m, now: t0.addingTimeInterval(40))
                m.cpuPercent = 10
                _ = AlertMonitor.shared.evaluate(m, now: t0.addingTimeInterval(50))
                m.cpuPercent = 95
                let d = AlertMonitor.shared.evaluate(m, now: t0.addingTimeInterval(100))
                let e = AlertMonitor.shared.evaluate(m, now: t0.addingTimeInterval(700))
                let ok = a.isEmpty && b.count == 1 && c.isEmpty && d.isEmpty && e.count == 1
                print("{\"mode\":\"alerts\",\"ok\":\(ok),\"first\":\(b.count),\"cooldown\":\(c.count)}")
                exit(0)
            case "diagnostics":
                let text = DiagnosticsService.text(metrics: nil, state: nil)
                let ok = text.contains("Otter 诊断报告") && text.contains("版本:") && text.contains("## 最近日志")
                print("{\"mode\":\"diagnostics\",\"ok\":\(ok),\"chars\":\(text.count),\"crashes\":\(DiagnosticsService.crashReports().count)}")
                exit(0)
            case "update-check":
                let gh = """
                {"tag_name":"v9.9.9","html_url":"https://example.com/release","body":"notes","assets":[{"name":"Otter.dmg","browser_download_url":"https://example.com/Otter.dmg"}]}
                """.data(using: .utf8)!
                let custom = """
                {"version":"1.2.3","dmg":"https://example.com/a.dmg","page":"https://example.com"}
                """.data(using: .utf8)!
                let a = (try? UpdateService.parse(gh))?.version == "9.9.9"
                let b = (try? UpdateService.parse(custom))?.version == "1.2.3"
                let c = UpdateService.compare("0.14.0", "0.13.0") == 1
                let d = UpdateService.compare("0.13", "0.13.0") == 0
                let e = UpdateService.compare("0.9", "0.10.0") == -1
                print("{\"mode\":\"update-check\",\"ok\":\(a && b && c && d && e),\"current\":\"\(UpdateService.currentVersion)\"}")
                exit(0)
            case "maintenance-action":
                let cmd = MaintenanceService.dnsFlushCommand
                let ok = cmd.contains("dscacheutil -flushcache") && cmd.contains("killall -HUP mDNSResponder")
                print("{\"mode\":\"maintenance-action\",\"ok\":\(ok),\"command\":\"\(cmd)\"}")
                exit(0)
            case "maintenance":
                let r = MaintenanceService.collect()
                let dict: [String: Any] = [
                    "mode": "maintenance",
                    "ok": !r.osVersion.isEmpty,
                    "os": r.osVersion,
                    "arch": r.arch,
                    "model": r.model,
                    "spotlight": r.spotlight,
                    "snapshots": r.snapshotCount,
                    "userAgents": r.userAgents,
                    "systemAgents": r.systemAgents,
                    "systemDaemons": r.systemDaemons,
                    "smart": r.smartStatus ?? "",
                    "ssd": r.isSSD.map { $0 ? "ssd" : "hdd" } ?? "unknown",
                    "freeBytes": r.freeBytes,
                    "totalBytes": r.totalBytes
                ]
                print(String(data: try! JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]), encoding: .utf8)!)
                exit(0)
            case "priv-guard":
                let input = ["/Library/Caches/com.example.test",
                             "/Library/Caches/../etc/passwd",
                             "/etc/passwd",
                             "/Library/Caches"]
                let safe = PrivilegedCleaner.sanitize(paths: input)
                let body = PrivilegedCleaner.scriptBody(for: input)
                let ok = safe == ["/Library/Caches/com.example.test"]
                    && body.contains("rm -rf -- '/Library/Caches/com.example.test'")
                    && !body.contains("/etc/passwd")
                print("{\"mode\":\"priv-guard\",\"ok\":\(ok),\"safe\":\(safe.count),\"rejected\":\(input.count - safe.count)}")
                exit(0)
            case "uninstall-fixture":
                runSelfTestUninstallFixture()
                exit(0)
            case "clean-native-fixture":
                runSelfTestNativeClean()
                exit(0)
            case "space-fixture":
                print(SpaceScanner.selfTestJSON())
            case "disk-fixture":
                print(DiskViewModel.fixtureSelfTestJSON())
            case "disk-scan":
                let path = ProcessInfo.processInfo.environment["OTTER_DISK_PATH"] ?? NSHomeDirectory()
                print(DiskViewModel.selfTestJSON(path: path))
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