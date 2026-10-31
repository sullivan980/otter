import AppKit
import SwiftUI

final class HUDWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class HUDWindowController {
    private let panel: HUDWindow
    private let state: AppState
    private var outsideMonitor: Any?
    private weak var anchorButton: NSStatusBarButton?

    init(state: AppState) {
        self.state = state
        panel = HUDWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered,
                          defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.contentView = NSHostingView(rootView: HUDView(state: state))
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(relativeTo button: NSStatusBarButton?) {
        if isVisible { hide() } else { show(relativeTo: button) }
    }

    func show(relativeTo button: NSStatusBarButton?) {
        anchorButton = button
        guard let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let menubar = max(24, screen.frame.maxY - screen.visibleFrame.maxY)
        var x = screen.frame.midX - size.width / 2
        if let win = button?.window { x = win.frame.midX - size.width / 2 }
        x = min(max(x, screen.frame.minX + 8), screen.frame.maxX - size.width - 8)
        let top = screen.frame.maxY - menubar - 4
        panel.setFrameOrigin(NSPoint(x: x, y: top - size.height))
        panel.orderFrontRegardless()
        panel.makeKey()
        state.hudVisible = true
        installOutsideMonitor()
    }

    func hide() {
        panel.orderOut(nil)
        state.hudVisible = false
        removeOutsideMonitor()
    }

    private func installOutsideMonitor() {
        guard outsideMonitor == nil else { return }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            let p = NSEvent.mouseLocation
            if self.panel.frame.contains(p) { return }
            if let win = self.anchorButton?.window, win.frame.contains(p) { return }
            self.hide()
        }
    }

    private func removeOutsideMonitor() {
        if let m = outsideMonitor { NSEvent.removeMonitor(m); outsideMonitor = nil }
    }
}
