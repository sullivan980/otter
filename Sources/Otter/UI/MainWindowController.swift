import AppKit
import SwiftUI

// MARK: - 主界面分区

enum MainSection: String, CaseIterable, Identifiable {
    case clean, uninstall, disk, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clean: return "清理"
        case .uninstall: return "卸载"
        case .disk: return "磁盘"
        case .settings: return "设置"
        }
    }
    var icon: String {
        switch self {
        case .clean: return "sparkles"
        case .uninstall: return "xmark.bin"
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
        win.backgroundColor = .windowBackgroundColor
        win.center()
        win.isReleasedWhenClosed = false
        super.init(window: win)

        win.contentView = NSHostingView(rootView: MainRootView(state: state))
        win.setFrameAutosaveName("OtterMainWindow")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func select(section: String) {
        if let s = MainSection(rawValue: section) { state.selectedSection = s.rawValue }
    }
}
