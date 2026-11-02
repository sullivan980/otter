import SwiftUI
import AppKit

/// 桌面实时小组件：比菜单栏宽，常驻显示 CPU/内存/磁盘/网络。
/// 注：macOS WidgetKit 的刷新受系统限流（分钟级），做不了秒级实时，
/// 所以这里用无边框浮层实现「桌面小组件」，数据与主界面同源（1–2 秒）。
struct DesktopWidgetView: View {
    @ObservedObject var state: AppState
    @ObservedObject var themeStore: ThemeStore
    var onClose: () -> Void

    private var theme: AppTheme { themeStore.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "water.waves")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text("Otter")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(3)
                }
                .buttonStyle(.plain)
            }

            let m = state.metrics
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(String(format: "%.0f", m.cpuPercent))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(m.cpuPercent >= 85 ? Color.orange : theme.accent)
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("CPU")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 3)
                Spacer()
            }

            HStack(spacing: 10) {
                mini("内存", m.memUsedPercent)
                mini("磁盘", m.diskUsedPercent)
            }
            HStack(spacing: 10) {
                Text("↑ \(Fmt.rate(m.upBytesPerSec))")
                Text("↓ \(Fmt.rate(m.downBytesPerSec))")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)

            coreBars(m.cpuCores)
        }
        .padding(13)
        .frame(width: 226)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        .preferredColorScheme(theme.isDark ? .dark : .light)
    }

    private func mini(_ name: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.system(size: 8.5)).foregroundStyle(.tertiary)
            HStack(spacing: 4) {
                Text(Fmt.percent(value))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule().fill(value >= 85 ? Color.orange : theme.accent)
                            .frame(width: max(2, geo.size.width * min(1, value / 100)))
                    }
                }
                .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func coreBars(_ cores: [Double]) -> some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(cores.prefix(8).enumerated()), id: \.offset) { _, v in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(theme.accent.opacity(0.35 + min(0.65, v / 100)))
                    .frame(height: max(3, 16 * min(1, v / 100)))
            }
            Spacer()
        }
        .frame(height: 16)
    }
}

final class DesktopWidgetController {
    static let shared = DesktopWidgetController()
    private var panel: NSPanel?
    private var state: AppState?
    private var themeStore: ThemeStore?

    private init() {}

    var isVisible: Bool { panel?.isVisible == true }

    func configure(state: AppState, themeStore: ThemeStore) {
        self.state = state
        self.themeStore = themeStore
    }

    func setVisible(_ visible: Bool) {
        if visible { show() } else { hide() }
    }

    func show() {
        guard let state = state, let themeStore = themeStore else { return }
        if let panel = panel {
            panel.orderFrontRegardless()
            return
        }
        let view = DesktopWidgetView(state: state, themeStore: themeStore,
                                     onClose: { [weak self] in self?.hide() })
        let hosting = NSHostingView(rootView: view)
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 226, height: 170),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.contentView = hosting
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = Prefs.shared.widgetAlwaysOnTop ? .floating : .normal
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false
        p.setFrameAutosaveName("OtterDesktopWidget")
        if p.frame.origin == .zero {
            if let screen = NSScreen.main {
                p.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 260,
                                         y: screen.visibleFrame.maxY - 240))
            }
        }
        p.orderFrontRegardless()
        panel = p
        Prefs.shared.desktopWidgetVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        Prefs.shared.desktopWidgetVisible = false
    }

    func applyLevel() {
        panel?.level = Prefs.shared.widgetAlwaysOnTop ? .floating : .normal
    }
}
