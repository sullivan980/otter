import SwiftUI
import AppKit

// MARK: - 主界面通用视觉组件
// 统一卡片、标题、空态、错误态、日志控制台等，保证四分区风格一致。

/// 侧边栏毛玻璃材质（macOS 原生 sidebar 效果）。
struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .sidebar
    }
}

/// 把窗口外观（标题栏/毛玻璃材质）切到主题对应的深浅色。
struct WindowAppearance: NSViewRepresentable {
    var isDark: Bool
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { v.window?.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua) }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {
        DispatchQueue.main.async { v.window?.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua) }
    }
}

/// 内容区背景：跟随主题渐变。
struct ContentBackground: View {
    var theme: AppTheme = ThemeStore.shared.theme
    var body: some View {
        theme.gradient
            .overlay(
                RadialGradient(colors: [theme.accent.opacity(theme.isDark ? 0.30 : 0.14), .clear],
                               center: .topTrailing, startRadius: 20, endRadius: 720)
            )
            .overlay(
                RadialGradient(colors: [Color(red: 0.45, green: 0.35, blue: 0.95).opacity(theme.isDark ? 0.18 : 0.06), .clear],
                               center: .bottomLeading, startRadius: 30, endRadius: 620)
            )
            .ignoresSafeArea()
    }
}

/// 分区标题行：大标题 + 说明 + 右侧操作。
struct SectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    private let trailing: Trailing

    init(title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 23, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 14)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// 卡片容器（浅色/深色自适应，1px 描边）。
struct PanelCard<Content: View>: View {
    var padding: CGFloat = 14
    private let content: Content

    init(padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    private var theme: AppTheme { ThemeStore.shared.theme }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    if theme.usesMaterial {
                        RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                        .fill(theme.panel.opacity(theme.usesMaterial ? 0.60 : 1.0))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                    .strokeBorder(theme.panelStroke, lineWidth: theme == .paperOtter ? 1.2 : 1)
            )
            .shadow(color: .black.opacity(theme == .paperOtter ? 0 : 0.07), radius: 8, y: 3)
    }
}

/// 小标题（卡片内的分组标题）。
struct SubHeader: View {
    let text: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(.system(size: 12, weight: .semibold))
            Spacer()
            if let trailing = trailing {
                Text(trailing).font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }
}

/// 状态横幅：info / success / warning / error。
enum BannerKind {
    case info, success, warning, error

    var color: Color {
        switch self {
        case .info: return .accentColor
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct StatusBanner: View {
    let kind: BannerKind
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(kind.color)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold))
                if let message = message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action).buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(kind.color.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(kind.color.opacity(0.22), lineWidth: 1)
        )
    }
}

/// 空态。
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

/// 服务未就绪占位（数据层未注入时显示，不崩溃、可重试）。
struct ServiceUnavailableView: View {
    let section: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text("\(section)服务未就绪").font(.system(size: 14, weight: .semibold))
            Text("数据层尚未注入服务。Otter 的指标、菜单栏与 HUD 不受影响；服务就绪后点「重新检测」即可。")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("重新检测", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

/// 流式日志控制台：只保留最后若干行，自动滚到底部。
struct ConsoleView: View {
    let lines: [String]
    var height: CGFloat = 132
    var title: String = "执行日志"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text("\(lines.count) 行").font(.system(size: 10)).foregroundStyle(.tertiary).monospacedDigit()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1.5) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        Color.clear.frame(height: 1).id("console-bottom")
                    }
                    .padding(9)
                }
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.22))
                )
                .onChange(of: lines.count) { _ in
                    proxy.scrollTo("console-bottom", anchor: .bottom)
                }
            }
        }
    }
}

/// 小型统计标签。
struct StatChip: View {
    let title: String
    let value: String
    var tint: Color = .secondary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(title).font(.system(size: 10.5)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint).monospacedDigit()
        }
    }
}

/// 左侧主界面侧栏指标小行。
struct SidebarMetricRow: View {
    let label: String
    let value: String
    let fraction: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.system(size: 10, weight: .medium)).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.10))
                    Capsule().fill(tint)
                        .frame(width: max(2, geo.size.width * min(max(fraction, 0), 1)))
                }
            }
            .frame(height: 3)
        }
    }
}

/// 搜索框（带放大镜，原生观感）。
struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

/// 分类色标（卸载残留等）。
struct KindTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(color.opacity(0.16)))
            .foregroundStyle(color)
    }
}

/// 分区底部操作条（固定不随滚动）。
struct BottomBar<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(ThemeStore.shared.theme.panel.opacity(0.94))
                .overlay(Rectangle().fill(ThemeStore.shared.theme.panelStroke).frame(height: 1), alignment: .top)
        )
    }
}
