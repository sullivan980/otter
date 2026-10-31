import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState!
    private var statusBar: StatusBarController!
    private var hud: HUDWindowController!
    private var mainWindow: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        bootstrapServices()

        // 验收/自测入口：OTTER_SELFTEST=metrics|clean|uninstall → 跑一次并退出
        if let mode = ProcessInfo.processInfo.environment["OTTER_SELFTEST"] {
            runSelfTest(mode: mode)
            exit(0)
        }

        state = AppState()
        state.sampler = RealMetricsSampler()
        state.start()

        hud = HUDWindowController(state: state)
        statusBar = StatusBarController(state: state, hud: hud)
        statusBar.install()

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

        // 首次启动引导（dev-shell 实现三步窗口）
        OnboardingController.shared.presentIfNeeded()
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