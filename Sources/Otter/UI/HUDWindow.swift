import AppKit
import Combine
import CoreGraphics
import SwiftUI

/// HUD 面板：无边框、不激活 App、可浮在全屏 Space 之上。
final class HUDWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // esc 收起
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}

/// HUD 窗口控制器：固定 400×520，锚定菜单栏图标正下方。
final class HUDWindowController {
    private let panel: HUDWindow
    private let state: AppState
    private var outsideMonitor: Any?
    private var localMonitor: Any?
    private weak var anchorButton: NSStatusBarButton?

    /// 固定尺寸（不随内容缩放）
    static let size = NSSize(width: 400, height: 520)

    init(state: AppState) {
        self.state = state
        panel = HUDWindow(contentRect: NSRect(origin: .zero, size: Self.size),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered,
                          defer: false)
        panel.title = "Otter 面板"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // 透明窗口需要一层底色，否则 SwiftUI 的 material 无法正确采样
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.onEscape = { [weak self] in self?.hide() }
        panel.contentView = NSHostingView(rootView: HUDView(state: state, onAction: { [weak self] section in
            self?.hide()
            DispatchQueue.main.async {
                if let section = section {
                    state.openMainSection?(section)
                } else {
                    state.openMainWindow?()
                }
            }
        }))
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(relativeTo button: NSStatusBarButton?) {
        if isVisible { hide() } else { show(relativeTo: button) }
    }

    func show(relativeTo button: NSStatusBarButton?) {
        anchorButton = button
        guard let screen = button?.window?.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        position(on: screen, anchor: button)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }, completionHandler: nil)
        state.hudVisible = true
        installOutsideMonitor()
    }

    func hide() {
        removeMonitors()
        state.hudVisible = false
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.10
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            // 动画期间若又被 show，则不要隐藏
            if self.state.hudVisible { self.panel.alphaValue = 1; return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        })
    }

    /// 锚定到菜单栏图标下方，钳制在屏幕可用区域内
    private func position(on screen: NSScreen, anchor: NSStatusBarButton?) {
        let size = panel.frame.size
        let visible = screen.visibleFrame

        var anchorRect = CGRect.zero
        if let btn = anchor, let win = btn.window {
            anchorRect = win.convertToScreen(btn.convert(btn.bounds, to: nil))
        }

        let menuBarVisible = screen.frame.maxY > visible.maxY + 1
        let topY = menuBarVisible ? visible.maxY : screen.frame.maxY
        let centerX = anchorRect.isEmpty ? screen.frame.midX : anchorRect.midX
        let x = min(max(centerX - size.width / 2, screen.frame.minX + 8),
                    screen.frame.maxX - size.width - 8)
        let y = topY - size.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - 点外部收起

    private func installOutsideMonitor() {
        guard outsideMonitor == nil, localMonitor == nil else { return }

        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.panel.isVisible else { return }
            let p = NSEvent.mouseLocation
            if self.panel.frame.contains(p) { return }
            if let win = self.anchorButton?.window, win.frame.contains(p) { return }
            self.hide()
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self = self, self.panel.isVisible else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53, self.panel.isKeyWindow {
                    self.hide()
                    return nil
                }
                return event
            }
            // 点在自己的 HUD / 菜单栏按钮上不算「点外部」
            if event.window === self.panel { return event }
            if let win = self.anchorButton?.window, event.window === win { return event }
            self.hide()
            return event
        }
    }

    private func removeMonitors() {
        if let m = outsideMonitor { NSEvent.removeMonitor(m); outsideMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }
}
