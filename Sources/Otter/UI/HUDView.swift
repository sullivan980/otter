import AppKit
import Combine
import SwiftUI

/// 毛玻璃底（浅色 / 深色都跟随系统）
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
    }
}

/// HUD 固定 400×520：5 指标 + TOP3 进程 + 清理/卸载/主界面。
/// 优先消费插件 manifest（PluginStore.activeId）；manifest 缺失时回退内置布局。
struct HUDView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var shell = ShellState.shared
    @ObservedObject private var plugins = PluginStore.shared
    @ObservedObject private var themeStore = ThemeStore.shared

    private var theme: AppTheme { themeStore.theme }

    /// 点操作按钮时回调（HUD 负责收起，壳层负责开主界面）
    var onAction: ((String?) -> Void)? = nil

    private var m: SystemMetrics { state.metrics }

    private var activePlugin: HUDPlugin? {
        plugins.plugin(id: plugins.activeId)
    }

    private var activeStyle: HUDPluginStyle? { activePlugin?.style }

    var body: some View {
        VStack(spacing: 8) {
            header

            Group {
                if let plugin = activePlugin, !plugin.rows.isEmpty {
                    pluginContent(plugin)
                } else {
                    builtInContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            actions
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(width: 400, height: 520)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                .strokeBorder(theme.panelStroke, lineWidth: 1)
        )
        .tint(theme.accent)
        .preferredColorScheme(theme.isDark ? .dark : .light)
    }

    // MARK: - 背景

    private var panelBackground: some View {
        ZStack {
            if theme.usesMaterial {
                VisualEffectBackground(material: .popover, blending: .behindWindow)
            }
            theme.gradient.opacity(theme.usesMaterial ? 0.55 : 1.0)
            LinearGradient(colors: [theme.accent.opacity(0.12), Color.clear],
                           startPoint: .topLeading, endPoint: .center)
        }
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "water.waves")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("系统状态")
                .font(.system(size: 13, weight: .semibold))
            HStack(spacing: 5) {
                HUDDot(on: !state.isPaused && m.isReady)
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(Self.clock(ctx.date))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 22)
    }

    private var statusText: String {
        if state.isPaused { return "已暂停" }
        return m.isReady ? "实时监控中" : "读取中…"
    }

    // MARK: - 内置布局（manifest 缺失时回退）

    private var builtInContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                if !m.isReady {
                    skeletonLayout
                } else {
                    bigCard(.cpu)
                    HStack(spacing: 8) {
                        percentCard(.mem)
                        percentCard(.disk)
                    }
                    networkCard
                    procsCard(title: "占用最高进程", trailing: "按 CPU")
                }
            }
            .padding(.bottom, 2)
        }
    }

    // MARK: - 插件布局（声明式 manifest）

    private func pluginContent(_ plugin: HUDPlugin) -> some View {
        let specs = rowSpecs(for: plugin)
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: CGFloat(plugin.style?.spacing ?? 8)) {
                if !m.isReady {
                    skeletonLayout
                } else {
                    ForEach(Array(specs.enumerated()), id: \.offset) { _, spec in
                        rowView(spec)
                    }
                }
            }
            .padding(.bottom, 2)
        }
    }

    private enum HUDRowSpec {
        case big(MetricKind)
        case bar(MetricKind)
        case ring(MetricKind)
        case textGroup([MetricKind])
        case procs(String?)
        case clock
        case uptime
        case divider
    }

    /// 把 manifest rows 归一成可渲染的块：相邻 text 行合并成一张卡；缺 procs 时补 TOP3。
    private func rowSpecs(for plugin: HUDPlugin) -> [HUDRowSpec] {
        var out: [HUDRowSpec] = []
        var buffer: [MetricKind] = []
        var hasProcs = false

        func flush() {
            if !buffer.isEmpty {
                out.append(.textGroup(buffer))
                buffer = []
            }
        }

        for row in plugin.rows {
            let metric = row.metric.lowercased()
            let style = row.style.lowercased()
            if style == "divider" || metric == "divider" {
                flush(); out.append(.divider); continue
            }
            if metric == "procs" { flush(); out.append(.procs(row.label)); hasProcs = true; continue }
            if metric == "clock" { flush(); out.append(.clock); continue }
            if metric == "uptime" { flush(); out.append(.uptime); continue }
            guard let kind = MetricKind.parse(metric) else { continue }
            switch style {
            case "big": flush(); out.append(.big(kind))
            case "bar": flush(); out.append(.bar(kind))
            case "ring": flush(); out.append(.ring(kind))
            default: buffer.append(kind)
            }
        }
        flush()
        if !hasProcs { out.append(.procs(nil)) }
        return out
    }

    @ViewBuilder
    private func rowView(_ spec: HUDRowSpec) -> some View {
        switch spec {
        case .big(let kind): bigCard(kind)
        case .bar(let kind): barCard(kind)
        case .ring(let kind): ringCard(kind)
        case .textGroup(let kinds): textGroupCard(kinds)
        case .procs(let label): procsCard(title: label ?? "占用最高进程", trailing: "按 CPU")
        case .clock: clockCard
        case .uptime: uptimeCard
        case .divider: Divider().padding(.vertical, 1)
        }
    }

    // MARK: - 卡片

    /// 大数字卡（CPU 主位）：数值 + 60 点火花线
    private func bigCard(_ kind: MetricKind) -> some View {
        let tint = statusTint(kind.load(m), base: kind.accent)
        return HUDCard(padding: 11) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(kind.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(kind.subtitle(m))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Text(kind.display(m))
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if kind == .cpu, !m.cpuCores.isEmpty {
                    coreBars(tint: tint)
                }
                if activeStyle?.showSparkline != false {
                    HUDSparkline(values: shell.normalizedHistory(kind, count: 60), tint: tint)
                        .frame(height: 24)
                }
            }
        }
    }

    /// 每核负载条（填充 CPU 卡空白，也方便看单核打满）。
    private func coreBars(tint: Color) -> some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(m.cpuCores.enumerated()), id: \.offset) { _, v in
                let f = min(max(v / 100, 0), 1)
                Capsule()
                    .fill(tint.opacity(0.22 + 0.7 * f))
                    .frame(width: 7, height: 4 + 14 * f)
            }
            Spacer(minLength: 4)
            Text("每核")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 18, alignment: .bottom)
    }

    /// 半宽百分比卡（内存 / 磁盘）
    private func percentCard(_ kind: MetricKind) -> some View {
        let tint = statusTint(kind.load(m), base: kind.accent)
        return HUDCard(padding: 11) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(kind.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(kind.display(m))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(kind.subtitle(m))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                HUDBar(fraction: kind.fraction(m), tint: tint, height: 4)
            }
        }
    }

    /// 横向进度卡（插件 bar 样式）
    private func barCard(_ kind: MetricKind) -> some View {
        let tint = statusTint(kind.load(m), base: kind.accent)
        return HUDCard(padding: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(kind.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(kind.display(m))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                HUDBar(fraction: kind.fraction(m), tint: tint, height: 5)
                Text(kind.subtitle(m))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    /// 环形卡（插件 ring 样式）
    private func ringCard(_ kind: MetricKind) -> some View {
        let tint = statusTint(kind.load(m), base: kind.accent)
        return HUDCard(padding: 11) {
            HStack(spacing: 12) {
                HUDRing(fraction: kind.fraction(m), tint: tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(kind.display(m))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(kind.subtitle(m))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// 连续 text 行合并卡（网络上下行等）
    private func textGroupCard(_ kinds: [MetricKind]) -> some View {
        HUDCard(padding: 10) {
            VStack(spacing: 6) {
                ForEach(Array(kinds.enumerated()), id: \.offset) { idx, kind in
                    if idx > 0 { Divider() }
                    HStack(spacing: 6) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(kind.accent)
                        Text(kind.title)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(kind.display(m))
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    /// 网络卡（内置布局用）
    private var networkCard: some View {
        HUDCard(padding: 11) {
            HStack(spacing: 0) {
                netColumn(.up)
                Divider().frame(height: 26).padding(.horizontal, 12)
                netColumn(.down)
                Spacer(minLength: 0)
            }
        }
    }

    private func netColumn(_ kind: MetricKind) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(kind.accent)
                Text(kind.title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text(kind.display(m))
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
        }
    }

    // MARK: - TOP3 进程

    private func procsCard(title: String, trailing: String?) -> some View {
        HUDCard(padding: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HUDSectionTitle(text: title, trailing: trailing)
                if !m.isReady {
                    ForEach(0..<3, id: \.self) { _ in
                        HUDSkeleton(height: 12)
                    }
                } else if m.topProcesses.isEmpty {
                    Text("暂无进程数据，采集中…")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    ForEach(Array(m.topProcesses.prefix(3).enumerated()), id: \.element.id) { idx, p in
                        processRow(p, rank: idx + 1)
                    }
                }
            }
        }
    }

    private func processRow(_ p: TopProcess, rank: Int) -> some View {
        HStack(spacing: 7) {
            Text("\(rank)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 10, alignment: .leading)
            Text(p.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            Text(Fmt.percent(p.cpuPercent))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(Fmt.bytes(Double(p.memBytes)))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 56, alignment: .trailing)
        }
    }

    // MARK: - 插件里的 clock / uptime 行

    private var clockCard: some View {
        HUDCard(padding: 11) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("当前时间")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(Self.clock(ctx.date))
                        .font(.system(size: 12, design: .monospaced))
                }
            }
        }
    }

    private var uptimeCard: some View {
        HUDCard(padding: 11) {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("已开机")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(m.isReady ? Fmt.uptime(m.uptime) : "--")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 加载态骨架

    private var skeletonLayout: some View {
        VStack(spacing: 8) {
            HUDCard {
                VStack(alignment: .leading, spacing: 9) {
                    HUDSkeleton(width: 86, height: 10)
                    HUDSkeleton(width: 128, height: 26)
                    HUDSkeleton(height: 34)
                }
            }
            HStack(spacing: 10) {
                HUDCard(padding: 11) {
                    VStack(alignment: .leading, spacing: 8) {
                        HUDSkeleton(width: 54, height: 9)
                        HUDSkeleton(width: 76, height: 20)
                        HUDSkeleton(height: 4)
                    }
                }
                HUDCard(padding: 11) {
                    VStack(alignment: .leading, spacing: 8) {
                        HUDSkeleton(width: 54, height: 9)
                        HUDSkeleton(width: 76, height: 20)
                        HUDSkeleton(height: 4)
                    }
                }
            }
            HUDCard(padding: 11) {
                HStack {
                    HUDSkeleton(width: 96, height: 12)
                    Spacer()
                    HUDSkeleton(width: 96, height: 12)
                }
            }
            HUDCard(padding: 11) {
                VStack(spacing: 9) {
                    HUDSkeleton(width: 92, height: 10)
                    ForEach(0..<3, id: \.self) { _ in HUDSkeleton(height: 12) }
                }
            }
        }
    }

    // MARK: - 底部操作

    private var actions: some View {
        HStack(spacing: 8) {
            actionButton("清理", systemImage: "trash", primary: false) { onAction?("clean") }
            actionButton("卸载", systemImage: "xmark.bin", primary: false) { onAction?("uninstall") }
            actionButton("主界面", systemImage: "rectangle.on.rectangle", primary: true) { onAction?(nil) }
        }
    }

    private func actionButton(_ title: String,
                              systemImage: String,
                              primary: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(primary ? theme.accent : Color.primary.opacity(0.07))
            )
            .foregroundStyle(primary ? (theme.isDark ? Color.black : Color.white) : Color.primary)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 工具

    /// 阈值着色：≥85 红 / ≥60 黄，否则用指标自身强调色
    private func statusTint(_ load: Double?, base: Color) -> Color {
        guard let v = load else { return base }
        if v >= ShellPrefs.dangerThreshold { return Color(nsColor: .systemRed) }
        if v >= ShellPrefs.warnThreshold { return Color(nsColor: .systemYellow) }
        return base
    }

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    static func clock(_ date: Date) -> String { clockFormatter.string(from: date) }
}
