import AppKit
import SwiftUI

// MARK: - 主界面分区

enum MainSection: String, CaseIterable, Identifiable {
    case clean, uninstall, space, disk, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clean: return "清理"
        case .uninstall: return "卸载"
        case .space: return "空间"
        case .disk: return "磁盘"
        case .settings: return "设置"
        }
    }
    var icon: String {
        switch self {
        case .clean: return "sparkles"
        case .uninstall: return "xmark.bin"
        case .space: return "shippingbox"
        case .disk: return "internaldrive"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - 主窗口
//
// 原生窗口：隐藏标题栏、内容延伸到顶部（侧栏毛玻璃透出），红绿灯悬浮在侧栏品牌区上方。
// 四个分区由 MainViews/ 下视图实现，分区状态由 MainRootView 持有。
final class MainWindowController: NSWindowController {
    private let state: AppState

    init(state: AppState) {
        self.state = state
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 660),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                           backing: .buffered,
                           defer: false)
        win.title = "Otter"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.minSize = NSSize(width: 820, height: 560)
        // 一体化玻璃窗：透明窗口 + 窗口级毛玻璃 + 圆角遮罩，SwiftUI 内容半透明叠在上面。
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.center()
        win.isReleasedWhenClosed = false
        super.init(window: win)

        let radius: CGFloat = 18
        let effect = NSVisualEffectView()
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: radius)

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = radius
        container.layer?.masksToBounds = true
        effect.autoresizingMask = [.width, .height]
        effect.frame = container.bounds
        container.addSubview(effect)

        let host = NSHostingView(rootView: MainRootView(state: state))
        host.autoresizingMask = [.width, .height]
        host.frame = container.bounds
        host.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(host)

        win.contentView = container
        win.setFrameAutosaveName("OtterMainWindow")
    }

    /// 窗口圆角遮罩（stretchable，用于 NSVisualEffectView.maskImage）
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let img = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        img.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        img.resizingMode = .stretch
        return img
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func select(section: String) {
        if let s = MainSection(rawValue: section) { state.selectedSection = s.rawValue }
    }
}