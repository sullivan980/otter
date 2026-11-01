import AppKit
import Combine
import SwiftUI

// MARK: - 菜单栏指标种类（菜单栏 / HUD / 引导共用）
//
// 格式规范集中在这里：
//   · 百分比不补零（7%，不写 007%）；
//   · 速率必须带紧凑单位（0B/s、820K/s、1.2M/s、1.5G/s）；
//   · 默认单色，只有 ≥85% 红、≥60% 黄（且需用户开关），绿色永不出现；
//   · 数据未就绪统一 "--" 占位，绝不崩。

/// 5 个可上菜单栏的指标。
enum MetricKind: String, CaseIterable, Identifiable {
    case cpu, mem, disk, up, down

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .mem: return "内存"
        case .disk: return "磁盘"
        case .up: return "上传"
        case .down: return "下载"
        }
    }

    /// SF Symbol 名（渲染时按当前深浅色解析颜色，保证菜单栏可见）
    var symbol: String {
        switch self {
        case .cpu: return "cpu"
        case .mem: return "memorychip"
        case .disk: return "internaldrive"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        }
    }

    var isRate: Bool { self == .up || self == .down }

    /// HUD 强调色（不用绿色，避免和「正常」语义冲突）
    var accent: Color {
        switch self {
        case .cpu: return Color(nsColor: .systemBlue)
        case .mem: return Color(nsColor: .systemPurple)
        case .disk: return Color(nsColor: .systemTeal)
        case .up: return Color(nsColor: .systemOrange)
        case .down: return Color(nsColor: .systemIndigo)
        }
    }

    /// 百分比指标返回 0...100，速率返回 B/s
    func numericValue(_ m: SystemMetrics) -> Double {
        switch self {
        case .cpu: return m.cpuPercent
        case .mem: return m.memUsedPercent
        case .disk: return m.diskUsedPercent
        case .up: return m.upBytesPerSec
        case .down: return m.downBytesPerSec
        }
    }

    /// 只有百分比指标参与阈值着色；速率不参与（避免误报）
    func load(_ m: SystemMetrics) -> Double? {
        isRate ? nil : numericValue(m)
    }

    func display(_ m: SystemMetrics) -> String {
        guard m.isReady else { return "--" }
        return isRate ? Fmt.rate(numericValue(m)) : Fmt.percent(numericValue(m))
    }

    /// HUD 卡片副标题
    func subtitle(_ m: SystemMetrics) -> String {
        guard m.isReady else { return "读取中…" }
        switch self {
        case .mem, .disk:
            let used = (self == .mem) ? Double(m.memUsedBytes) : Double(m.diskUsedBytes)
            let total = (self == .mem) ? Double(m.memTotalBytes) : Double(m.diskTotalBytes)
            guard total > 0 else { return "-- / --" }
            return Fmt.bytes(used) + " / " + Fmt.bytes(total)
        case .cpu:
            return m.coreCount > 0 ? "\(m.coreCount) 核 · 已开机 \(Fmt.uptime(m.uptime))" : "读取中…"
        case .up, .down:
            let peak = ShellState.shared.historyValues(self, count: 60).max() ?? 0
            return peak > 0 ? "近期峰值 " + Fmt.rate(peak) : "实时速率"
        }
    }

    /// 采样区间内相对比例 0...1（速率按近期峰值相对化）
    func fraction(_ m: SystemMetrics) -> Double {
        if isRate {
            let peak = ShellState.shared.historyValues(self, count: 60).max() ?? 0
            guard peak > 0 else { return 0 }
            return min(max(numericValue(m) / peak, 0), 1)
        }
        return min(max(numericValue(m) / 100, 0), 1)
    }

    static func parse(_ raw: String) -> MetricKind? { MetricKind(rawValue: raw) }
}

// MARK: - 菜单栏 4 预设

enum MenuBarPreset: String, CaseIterable, Identifiable {
    case minimal, dual, single, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal: return "极简"
        case .dual: return "双指标"
        case .single: return "单指标 + 趋势"
        case .custom: return "自定义"
        }
    }

    var subtitle: String {
        switch self {
        case .minimal: return "只留獭图标，悬停看详情"
        case .dual: return "CPU + 内存，默认推荐"
        case .single: return "挑一个指标 + 8 格迷你趋势"
        case .custom: return "5 个指标自由勾选与排序"
        }
    }

    /// 引导 / 设置页示意文本
    var preview: String {
        switch self {
        case .minimal: return "獭图标"
        case .dual: return "42%  61%"
        case .single: return "42%  ▁▃▅▂▇▆▃▂"
        case .custom: return "42%  61%  78%"
        }
    }

    static func current() -> MenuBarPreset {
        MenuBarPreset(rawValue: Prefs.shared.menuBarPreset) ?? .dual
    }
}

// MARK: - 壳层补充常量

enum ShellPrefs {
    /// 壳层偏好变化通知：改完预设/排序后发一下，菜单栏立即刷新
    static let changedNotification = Notification.Name("OtterShellPrefsChanged")

    /// 整条菜单栏宽度预算（pt）：超限按「去趋势 → 只留主指标 → 只留图标」降级
    static let menuBarWidthBudget: CGFloat = 120

    /// 阈值：只有这两级，绿色永不出现
    static let warnThreshold = 60.0
    static let dangerThreshold = 85.0

    /// 菜单栏阈值色（关闭着色或速率指标返回 labelColor）
    static func menuBarColor(load: Double?, colorByLoad: Bool) -> NSColor {
        guard colorByLoad, let v = load else { return .labelColor }
        if v >= dangerThreshold { return .systemRed }
        if v >= warnThreshold { return .systemYellow }
        return .labelColor
    }
}

// MARK: - 趋势历史（菜单栏趋势 + HUD 火花线共用）

/// 只保存最近 60 个采样点，不做任何持久化。
final class ShellState: ObservableObject {
    static let shared = ShellState()

    /// 每个指标最近 60 个采样（百分比 0...100 / 速率 B/s）
    @Published private(set) var history: [String: [Double]] = [:]

    private var lastStamp: Date = .distantPast

    private init() {}

    /// 喂入一次采样（主线程调用；同一 timestamp 不重复计数）
    func ingest(_ m: SystemMetrics) {
        guard m.isReady else { return }
        guard m.timestamp != lastStamp else { return }
        lastStamp = m.timestamp
        var h = history
        for kind in MetricKind.allCases {
            var arr = h[kind.rawValue] ?? []
            arr.append(kind.numericValue(m))
            if arr.count > 60 { arr.removeFirst(arr.count - 60) }
            h[kind.rawValue] = arr
        }
        history = h
    }

    /// 最近 count 个历史点（不足时左补 0，保证固定格数）
    func historyValues(_ kind: MetricKind, count: Int) -> [Double] {
        let arr = history[kind.rawValue] ?? []
        if arr.count >= count { return Array(arr.suffix(count)) }
        return Array(repeating: 0, count: count - arr.count) + arr
    }

    /// 归一化到 0...1：百分比 /100；速率按近期峰值相对化
    func normalizedHistory(_ kind: MetricKind, count: Int) -> [Double] {
        let values = historyValues(kind, count: count)
        if kind.isRate {
            let peak = values.max() ?? 0
            guard peak > 0 else { return values.map { _ in 0 } }
            return values.map { min(max($0 / peak, 0), 1) }
        }
        return values.map { min(max($0 / 100, 0), 1) }
    }
}

// MARK: - 菜单栏图片渲染（深浅色自动反色）

enum MenuBarGlyph {
    /// 当前菜单栏文字色（按系统深浅色解析）
    static func currentLabelColor() -> NSColor {
        var color = NSColor.labelColor
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance { color = NSColor.labelColor }
        return color
    }

    /// SF Symbol 着色图。不用 template 附件：模板图在 NSTextAttachment 里不保证反色，
    /// 这里直接按当前外观解析成黑/白，配合 refresh 的外观签名重建。
    static func symbol(_ name: String, pointSize: CGFloat = 11, weight: NSFont.Weight = .medium, color: NSColor) -> NSImage? {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        let sizeCfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        let cfg = sizeCfg.applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        guard let img = base.withSymbolConfiguration(cfg) else { return nil }
        img.isTemplate = false
        return img
    }

    /// 8 格迷你趋势图（柱条）
    static func trend(_ values: [Double], color: NSColor, size: NSSize = NSSize(width: 27, height: 11)) -> NSImage {
        let img = NSImage(size: size, flipped: false) { rect in
            let n = values.count
            guard n > 0 else { return true }
            let gap: CGFloat = 1.6
            let barW = max(1, (rect.width - gap * CGFloat(n - 1)) / CGFloat(n))
            color.setFill()
            for (i, v) in values.enumerated() {
                let h = max(1.6, CGFloat(min(max(v, 0), 1)) * rect.height)
                let r = NSRect(x: CGFloat(i) * (barW + gap), y: 0, width: barW, height: h)
                NSBezierPath(roundedRect: r, xRadius: barW / 2.4, yRadius: barW / 2.4).fill()
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    /// 图片 → 文本附件，按字体 capHeight 垂直居中
    static func attachment(_ image: NSImage, font: NSFont) -> NSAttributedString {
        let att = NSTextAttachment()
        att.image = image
        let y = (font.capHeight - image.size.height) / 2
        att.bounds = CGRect(x: 0, y: y, width: image.size.width, height: image.size.height)
        return NSAttributedString(attachment: att)
    }

    /// 獭模板图标（菜单栏品牌 + 极简预设 / 降级用；NSButton.image 会正确模板化反色）
    static func brandTemplate() -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 2.2, y: 11.2, width: 4.4, height: 4.4)).fill()
            NSBezierPath(ovalIn: NSRect(x: 11.4, y: 11.2, width: 4.4, height: 4.4)).fill()
            NSBezierPath(ovalIn: NSRect(x: 1.4, y: 5.2, width: 15.2, height: 10.0)).fill()
            let ripple = NSBezierPath()
            ripple.move(to: NSPoint(x: 1.2, y: 3.0))
            ripple.curve(to: NSPoint(x: 16.8, y: 3.0),
                         controlPoint1: NSPoint(x: 5.4, y: 5.6),
                         controlPoint2: NSPoint(x: 12.6, y: 0.6))
            ripple.lineWidth = 1.5
            ripple.lineCapStyle = .round
            NSColor.black.setStroke()
            ripple.stroke()
            return true
        }
        img.isTemplate = true
        return img
    }
}

// MARK: - HUD 通用组件（深浅色自适应：全部用 Color.primary 叠加，不写死白/黑）

/// 卡片容器：半透明底 + 细描边
struct HUDCard<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder var content: () -> Content

    private var theme: AppTheme { ThemeStore.shared.theme }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: max(6, theme.radius - 4), style: .continuous)
                    .fill(theme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(6, theme.radius - 4), style: .continuous)
                    .strokeBorder(theme.panelStroke, lineWidth: 1)
            )
    }
}

/// 迷你火花线（输入已归一化到 0...1）
struct HUDSparkline: View {
    var values: [Double]
    var tint: Color
    var lineWidth: CGFloat = 1.6
    var filled: Bool = true

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                if pts.count >= 2 {
                    if filled {
                        areaPath(pts, size: geo.size)
                            .fill(
                                LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0.02)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                    }
                    Path { p in p.addLines(pts) }
                        .stroke(tint.opacity(0.92),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                } else {
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                    }
                    .stroke(tint.opacity(0.18), lineWidth: 1)
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count >= 2, size.width > 0, size.height > 0 else { return [] }
        let inset: CGFloat = 1
        let h = max(1, size.height - inset * 2)
        return values.enumerated().map { i, v in
            let x = CGFloat(i) / CGFloat(values.count - 1) * (size.width - inset * 2) + inset
            let y = size.height - inset - CGFloat(min(max(v, 0), 1)) * h
            return CGPoint(x: x, y: y)
        }
    }

    private func areaPath(_ pts: [CGPoint], size: CGSize) -> Path {
        Path { p in
            p.move(to: CGPoint(x: pts[0].x, y: size.height))
            p.addLines(pts)
            p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: size.height))
            p.closeSubpath()
        }
    }
}

/// 环形进度（插件 manifest 的 ring 样式）
struct HUDRing: View {
    var fraction: Double
    var tint: Color
    var size: CGFloat = 46
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

/// 细进度条
struct HUDBar: View {
    var fraction: Double
    var tint: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// 加载占位块
struct HUDSkeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat = 11
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.primary.opacity(0.09))
            .frame(width: width, height: height)
    }
}

/// 小节标题
struct HUDSectionTitle: View {
    var text: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// 实时/暂停状态点
struct HUDDot: View {
    var on: Bool
    var body: some View {
        Circle()
            .fill(on ? Color(nsColor: .systemGreen) : Color.primary.opacity(0.25))
            .frame(width: 6, height: 6)
    }
}
// @otter-end
