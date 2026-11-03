import SwiftUI
import AppKit

// MARK: - 主界面根视图（侧栏 + 四分区）
//
// 分区状态由根视图持有（@StateObject），切换分区不丢失扫描/清理进度。
struct MainRootView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var themeStore = ThemeStore.shared
    @ObservedObject private var results = OperationResultCenter.shared

    private var theme: AppTheme { themeStore.theme }

    @StateObject private var clean = CleanViewModel()
    @StateObject private var uninstall = UninstallViewModel()
    @StateObject private var disk = DiskViewModel()
    @StateObject private var space = SpaceViewModel()
    @StateObject private var maintenance = MaintenanceViewModel()
    @StateObject private var startup = StartupViewModel()

    var body: some View {
        ZStack {
            // 半透明主题底：叠在窗口级毛玻璃上，形成一体化的玻璃面。
            ContentBackground(theme: theme)
                .opacity(theme.usesMaterial ? 0.60 : 0.92)
            HStack(spacing: 0) {
                MainSidebar(state: state)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(theme.isDark ? 0.10 : 0.35), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .overlay(alignment: .topTrailing) {
            if let result = results.current {
                OperationResultCard(result: result)
                    .padding(.top, 48)
                    .padding(.trailing, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: results.current?.id)
        .background(WindowAppearance(isDark: theme.isDark).frame(width: 0, height: 0))
        .tint(theme.accent)
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 800, minHeight: 540)
    }

    @ViewBuilder
    private var content: some View {
        switch MainSection(rawValue: state.selectedSection) ?? .clean {
        case .clean:
            CleanView(model: clean)
        case .uninstall:
            UninstallView(model: uninstall)
        case .space:
            SpaceView(model: space)
        case .startup:
            StartupView(model: startup)
        case .maintenance:
            MaintenanceView(model: maintenance)
        case .disk:
            DiskView(model: disk)
        case .settings:
            SettingsView(state: state)
        }
    }
}

// MARK: - 侧栏
struct MainSidebar: View {
    @ObservedObject var state: AppState

    private var current: MainSection { MainSection(rawValue: state.selectedSection) ?? .clean }
    private var theme: AppTheme { ThemeStore.shared.theme }

    /// 侧栏不再单独铺底：与内容共用同一块窗口玻璃，只叠一层极淡的高光，形成一体化。
    private var sidebarBackground: some View {
        LinearGradient(
            colors: ThemeStore.shared.theme.usesMaterial
                ? [Color.white.opacity(0.055), Color.white.opacity(0.012)]
                : [ThemeStore.shared.theme.sidebar.opacity(0.55), ThemeStore.shared.theme.sidebar.opacity(0.30)],
            startPoint: .top, endPoint: .bottom
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.top, 38)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            VStack(spacing: 2) {
                ForEach(MainSection.allCases) { section in
                    navRow(section)
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 12)
            metricsFooter
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(width: 204)
        .background(sidebarBackground)
    }

    private var brand: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.62)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: "water.waves")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Otter").font(.system(size: 15, weight: .bold))
                Text(L("系统守护者", "System Guardian")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func navRow(_ section: MainSection) -> some View {
        let selected = current == section
        return Button {
            state.selectedSection = section.rawValue
        } label: {
            HStack(spacing: 9) {
                Image(systemName: section.icon)
                    .font(.system(size: 12.5, weight: .medium))
                    .frame(width: 17)
                Text(section.title).font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var metricsFooter: some View {
        let m = state.metrics
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Circle()
                    .fill(m.isReady ? Color.green : Color.secondary)
                    .frame(width: 5, height: 5)
                Text(L("实时状态", "Live Status")).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(m.isReady ? L("运行中", "Running") : L("启动中", "Starting"))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
            SidebarMetricRow(label: "CPU", value: Fmt.percent(m.cpuPercent),
                             fraction: m.cpuPercent / 100,
                             tint: m.cpuPercent >= 85 ? .red : (m.cpuPercent >= 60 ? .orange : .green))
            SidebarMetricRow(label: L("内存", "Memory"), value: Fmt.percent(m.memUsedPercent),
                             fraction: m.memUsedPercent / 100,
                             tint: m.memUsedPercent >= 85 ? .red : (m.memUsedPercent >= 60 ? .orange : .blue))
            SidebarMetricRow(label: L("磁盘", "Disk"), value: Fmt.percent(m.diskUsedPercent),
                             fraction: m.diskUsedPercent / 100, tint: .teal)
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up").font(.system(size: 8, weight: .bold)).foregroundStyle(.purple)
                    Text(Fmt.rate(m.upBytesPerSec)).font(.system(size: 9.5)).monospacedDigit()
                }
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down").font(.system(size: 8, weight: .bold)).foregroundStyle(.cyan)
                    Text(Fmt.rate(m.downBytesPerSec)).font(.system(size: 9.5)).monospacedDigit()
                }
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }
}