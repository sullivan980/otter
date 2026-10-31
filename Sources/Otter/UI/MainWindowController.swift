import AppKit
import SwiftUI

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

final class MainWindowController: NSWindowController {
    private let state: AppState

    init(state: AppState) {
        self.state = state
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable],
                           backing: .buffered,
                           defer: false)
        win.title = "Otter"
        win.titlebarAppearsTransparent = true
        win.minSize = NSSize(width: 760, height: 520)
        win.center()
        win.isReleasedWhenClosed = false
        super.init(window: win)
        win.contentView = NSHostingView(rootView: MainView(state: state))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func select(section: String) {
        if let s = MainSection(rawValue: section) { state.selectedSection = s.rawValue }
    }
}

/// 主界面占位：dev-ui 负责实现四个分区。
struct MainView: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Otter").font(.system(size: 17, weight: .semibold)).padding(.bottom, 12)
                ForEach(MainSection.allCases) { s in
                    Button {
                        state.selectedSection = s.rawValue
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: s.icon).frame(width: 18)
                            Text(s.title)
                            Spacer()
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(state.selectedSection == s.rawValue ? Color.white.opacity(0.10) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(14)
            .frame(width: 180)
            .background(Color.black.opacity(0.16))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text(MainSection(rawValue: state.selectedSection)?.title ?? "")
                    .font(.system(size: 22, weight: .semibold))
                Text("分区开发中，由 dev-ui 实现。")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}
