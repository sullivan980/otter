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
                if let plugin = activePlugin, plugin.layout == "stack" {
                    stackContent(plugin)
                } else if let plugin = activePlugin, !plugin.rows.isEmpty {
                    pluginContent(plugin)
                } else {
                    builtInContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if activePlugin?.layout == "stack" {
                stackActions
            } else {
                actions
            }
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
            Text(L("系统状态", "System Status"))
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
        if state.isPaused { return L("已暂停", "Paused") }
        return m.isReady ? L("实时监控中", "Live") : L("读取中…", "Loading…")
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
                    procsCard(title: L("占用最高进程", "Top Processes"), trailing: L("按 CPU", "By CPU"))
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
        case .procs(let label): procsCard(title: label ?? L("占用最高进程", "Top Processes"), trailing: L("按 CPU", "By CPU"))
        case .clock: clockCard
        case .uptime: uptimeCard
        case .divider: Divider().padding(.vertical, 1)
        }
    }

    // MARK: - 纵向堆叠布局（n2，0.4 默认）
    //
    // 5 个模块：CPU（曲线 + 8 核）/ 内存 / 磁盘 / 网络 / TOP3。
    // 高度固定铺满 400×520，皮肤/强调色/圆角由主题和插件 style 控制，排版由 typeface 控制。

    private var stackTypefaceDesign: Font.Design? {
        switch activeStyle?.typeface {
        case "mono": return .monospaced
        case "serif": return .serif
        case "rounded": return .rounded
        default: return nil
        }
    }

    /// 启动初期历史为空时用第一个非零点补齐左侧，避免曲线长时间贴底。
    private func warmHistory(_ kind: MetricKind, count: Int) -> [Double] {
        var values = shell.normalizedHistory(kind, count: count)
        if let idx = values.firstIndex(where: { $0 > 0 }), idx > 0 {
            let seed = values[idx]
            for i in 0..<idx { values[i] = seed }
        }
        return values
    }

    private func numFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        if let design = stackTypefaceDesign {
            return .system(size: size, weight: weight, design: design)
        }
        return .system(size: size, weight: weight)
    }

    private var cpuTint: Color { theme.accent }
    private var memTint: Color { Color(nsColor: .systemOrange) }
    private var diskTint: Color { Color(nsColor: .systemPurple) }
    private var netTint: Color { Color(nsColor: .systemGreen) }

    private func stackContent(_ plugin: HUDPlugin) -> some View {
        let gap = CGFloat(plugin.style?.spacing ?? 9)
        return VStack(spacing: gap) {
            stackCPU
            HStack(spacing: 8) {
                stackMem
                stackDisk
            }
            stackNet
            stackTop
        }
    }

    private func stackLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .kerning(1.1)
            .foregroundStyle(.secondary)
    }

    private var stackCPU: some View {
        HUDCard(padding: 9) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    stackLabel("CPU")
                    Text(m.coreCount > 0 ? "\(m.coreCount) \(L("核", "cores")) · \(L("已开机", "Uptime")) \(Fmt.uptime(m.uptime))" : L("读取中…", "Loading…"))
                        .font(.system(size: 8.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(MetricKind.cpu.display(m))
                        .font(numFont(21))
                        .monospacedDigit()
                }
                HUDAreaChart(values: warmHistory(.cpu, count: 48), tint: cpuTint)
                    .frame(height: 44)
                coreGrid(tint: cpuTint)
            }
        }
        .frame(height: 152)
    }

    private func coreGrid(tint: Color) -> some View {
        let cores = Array(m.cpuCores.prefix(8))
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                         alignment: .leading, spacing: 3) {
            if cores.isEmpty {
                Text(L("每核读取中…", "Reading cores…"))
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(Array(cores.enumerated()), id: \.offset) { idx, value in
                    HStack(spacing: 5) {
                        Text("C\(idx + 1)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.10))
                                Capsule()
                                    .fill(tint)
                                    .frame(width: max(2, geo.size.width * CGFloat(min(max(value / 100, 0), 1))))
                            }
                        }
                        .frame(height: 4)
                        Text("\(Int(value.rounded()))")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, alignment: .trailing)
                    }
                    .frame(height: 10)
                }
            }
        }
    }

    private var stackMem: some View {
        HUDCard(padding: 9) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    stackLabel(L("内存", "Memory"))
                    Spacer(minLength: 2)
                    Text(MetricKind.mem.display(m))
                        .font(numFont(19))
                        .monospacedDigit()
                }
                Text(m.memTotalBytes > 0
                     ? "\(Fmt.bytes(Double(m.memUsedBytes))) / \(Fmt.bytes(Double(m.memTotalBytes)))"
                     : "读取中…")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                HUDAreaChart(values: warmHistory(.mem, count: 40), tint: memTint)
                    .frame(height: 32)
            }
        }
        .frame(height: 94)
    }

    private var stackDisk: some View {
        HUDCard(padding: 9) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    stackLabel(L("磁盘", "Disk"))
                    Spacer(minLength: 2)
                    Text(MetricKind.disk.display(m))
                        .font(numFont(19))
                        .monospacedDigit()
                }
                Text(m.diskTotalBytes > 0
                     ? "\(Fmt.bytes(Double(m.diskUsedBytes))) / \(Fmt.bytes(Double(m.diskTotalBytes)))"
                     : "读取中…")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                HUDBar(fraction: min(max(m.diskUsedPercent / 100, 0), 1), tint: diskTint, height: 6)
                    .frame(height: 6)
                    .padding(.top, 8)
                HStack(spacing: 4) {
                    Text("0")
                    Spacer(minLength: 2)
                    Text(m.diskTotalBytes > 0 ? Fmt.bytes(Double(m.diskTotalBytes)) : "--")
                }
                .font(.system(size: 7.5, design: .monospaced))
                .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 94)
    }

    private var stackNet: some View {
        HUDCard(padding: 9) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    stackLabel(L("网络", "Network"))
                    Text(L("实时速率", "Live rate")).font(.system(size: 8.5)).foregroundStyle(.tertiary)
                    Spacer()
                }
                netRow(.up, tint: netTint)
                netRow(.down, tint: netTint)
            }
        }
        .frame(height: 80)
    }

    private func netRow(_ kind: MetricKind, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: kind.symbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 10)
            Text(kind.display(m))
                .font(numFont(12, weight: .semibold))
                .monospacedDigit()
                .frame(width: 62, alignment: .leading)
            HUDAreaChart(values: warmHistory(kind, count: 36), tint: tint)
                .frame(height: 12)
        }
    }

    private var stackTop: some View {
        HUDCard(padding: 7) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    stackLabel(L("TOP 进程", "Top Processes"))
                    Spacer()
                    Text(L("按 CPU", "By CPU"))
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                if m.topProcesses.isEmpty {
                    Text(L("暂无进程数据，采集中…", "No process data yet…"))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 30)
                } else {
                    ForEach(Array(m.topProcesses.prefix(3).enumerated()), id: \.element.id) { idx, p in
                        HStack(spacing: 6) {
                            Text("\(idx + 1)")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(width: 8, alignment: .leading)
                            Text(p.name)
                                .font(.system(size: 9.5))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Text(Fmt.percent(p.cpuPercent))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("退出「(p.name)」") { confirmKill(p, force: false) }
                            Button("强制退出「(p.name)」", role: .destructive) { confirmKill(p, force: true) }
                        }
                        .help("右键可退出该进程")
                    }
                }
            }
        }
        .frame(height: 68)
    }

    private var stackActions: some View {
        HStack(spacing: 8) {
            stackButton(L("清理", "Clean"), primary: false) { onAction?("clean") }
            stackButton(L("卸载", "Uninstall"), primary: false) { onAction?("uninstall") }
            stackButton(L("主界面", "Main"), primary: true) { onAction?(nil) }
        }
    }

    private func stackButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(primary ? theme.accent : Color.primary.opacity(0.07))
                )
                .foregroundStyle(primary ? (theme.isDark ? Color.black : Color.white) : Color.primary)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
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
            Text(L("每核", "Cores"))
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
                    Text(L("暂无进程数据，采集中…", "No process data yet…"))
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
        .contentShape(Rectangle())
        .contextMenu {
            Button("退出「(p.name)」") { confirmKill(p, force: false) }
            Button("强制退出「(p.name)」", role: .destructive) { confirmKill(p, force: true) }
        }
    }

    private func confirmKill(_ p: TopProcess, force: Bool) {
        let alert = NSAlert()
        alert.messageText = force ? L("强制退出", "Force quit") + " \(p.name)?" : L("退出", "Quit") + " \(p.name)?"
        alert.informativeText = force
            ? L("会立即结束进程（SIGKILL），未保存的数据可能丢失。", "Sends SIGKILL immediately; unsaved data may be lost.")
            : L("会请求进程正常退出（SIGTERM）。", "Asks the process to quit normally (SIGTERM).")
        alert.alertStyle = force ? .critical : .warning
        alert.addButton(withTitle: force ? L("强制退出", "Force Quit") : L("退出", "Quit"))
        alert.addButton(withTitle: L("取消", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if case .failure(let error) = ProcessService.terminate(pid: p.id, force: force) {
            OperationResultCenter.shared.post(kind: .error, title: L("退出失败", "Failed to Quit"), message: error.localizedDescription)
        } else {
            OperationResultCenter.shared.post(kind: .success, title: L("已请求退出", "Quit Requested"), message: p.name)
        }
    }

    // MARK: - 插件里的 clock / uptime 行

    private var clockCard: some View {
        HUDCard(padding: 11) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(L("当前时间", "Time"))
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
                Text(L("已开机", "Uptime"))
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
            actionButton(L("清理", "Clean"), systemImage: "trash", primary: false) { onAction?("clean") }
            actionButton(L("卸载", "Uninstall"), systemImage: "xmark.bin", primary: false) { onAction?("uninstall") }
            actionButton(L("主界面", "Main"), systemImage: "rectangle.on.rectangle", primary: true) { onAction?(nil) }
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