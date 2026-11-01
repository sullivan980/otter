import SwiftUI

/// 主题：内置 A–E + 用户 JSON（~/Library/Application Support/Otter/themes/*.json）。
/// 用户主题 id 与内置相同时可覆盖内置，便于不重装应用迭代样式。
struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let tagline: String
    let isDark: Bool
    let accent: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let sidebar: Color
    let panel: Color
    let panelStroke: Color
    let radius: CGFloat
    let usesMaterial: Bool
    let isBuiltin: Bool

    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool { lhs.id == rhs.id }

    var swatches: [Color] { [backgroundTop, backgroundBottom, accent] }
    var gradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: 内置主题

    static let riverMist = AppTheme(
        id: "A", name: "河岸晨雾", tagline: "淡水青蓝 · 安静干净", isDark: false,
        accent: Color(red: 0.18, green: 0.49, blue: 0.56),
        backgroundTop: Color(red: 0.95, green: 0.97, blue: 0.97),
        backgroundBottom: Color(red: 0.85, green: 0.91, blue: 0.93),
        sidebar: Color(red: 0.94, green: 0.97, blue: 0.97),
        panel: Color.white.opacity(0.72),
        panelStroke: Color.black.opacity(0.06),
        radius: 14, usesMaterial: true, isBuiltin: true)

    static let onsen = AppTheme(
        id: "B", name: "温泉汤屋", tagline: "米白陶土 · 蒸汽柔光", isDark: false,
        accent: Color(red: 0.75, green: 0.42, blue: 0.25),
        backgroundTop: Color(red: 0.98, green: 0.94, blue: 0.89),
        backgroundBottom: Color(red: 0.94, green: 0.85, blue: 0.75),
        sidebar: Color(red: 0.97, green: 0.92, blue: 0.86),
        panel: Color(red: 1.0, green: 0.98, blue: 0.95).opacity(0.92),
        panelStroke: Color.black.opacity(0.08),
        radius: 18, usesMaterial: false, isBuiltin: true)

    static let deepDive = AppTheme(
        id: "C", name: "深潜", tagline: "深海荧色 · 夜间低刺激", isDark: true,
        accent: Color(red: 0.31, green: 0.82, blue: 0.77),
        backgroundTop: Color(red: 0.04, green: 0.13, blue: 0.16),
        backgroundBottom: Color(red: 0.02, green: 0.08, blue: 0.10),
        sidebar: Color(red: 0.03, green: 0.10, blue: 0.13),
        panel: Color(red: 0.05, green: 0.15, blue: 0.18),
        panelStroke: Color(red: 0.43, green: 0.91, blue: 0.86).opacity(0.16),
        radius: 14, usesMaterial: false, isBuiltin: true)

    static let paperOtter = AppTheme(
        id: "D", name: "纸水獭", tagline: "米纸墨线 · 手账感", isDark: false,
        accent: Color(red: 0.25, green: 0.42, blue: 0.35),
        backgroundTop: Color(red: 0.95, green: 0.93, blue: 0.88),
        backgroundBottom: Color(red: 0.90, green: 0.87, blue: 0.80),
        sidebar: Color(red: 0.95, green: 0.93, blue: 0.88),
        panel: Color(red: 0.98, green: 0.97, blue: 0.94),
        panelStroke: Color.black.opacity(0.22),
        radius: 6, usesMaterial: false, isBuiltin: true)

    static let liquidGlass = AppTheme(
        id: "E", name: "水波玻璃", tagline: "液态玻璃 · 最系统原生", isDark: true,
        accent: Color(red: 0.43, green: 0.83, blue: 0.91),
        backgroundTop: Color(red: 0.05, green: 0.13, blue: 0.20),
        backgroundBottom: Color(red: 0.03, green: 0.09, blue: 0.13),
        sidebar: Color.white.opacity(0.05),
        panel: Color.white.opacity(0.09),
        panelStroke: Color.white.opacity(0.16),
        radius: 18, usesMaterial: true, isBuiltin: true)

    static let builtins: [AppTheme] = [.riverMist, .onsen, .deepDive, .paperOtter, .liquidGlass]
    static let fallback: AppTheme = .liquidGlass
}

// MARK: - JSON 主题（用户可放 ~/Library/Application Support/Otter/themes/*.json）

private struct ThemeFile: Codable {
    var id: String
    var name: String
    var tagline: String?
    var dark: Bool?
    var accent: String
    var backgroundTop: String
    var backgroundBottom: String
    var sidebar: String?
    var panel: String?
    var panelStroke: String?
    var radius: Double?
    var material: Bool?
}

extension Color {
    /// 支持 #RGB / #RRGGBB / #RRGGBBAA。
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let hasAlpha = s.count == 8
        let r, g, b, a: Double
        if hasAlpha {
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        } else {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// 主题仓库：内置 + 用户 JSON；用户同 id 覆盖内置（热迭代，不重装应用）。
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published private(set) var themes: [AppTheme] = AppTheme.builtins
    @Published private(set) var loadErrors: [String] = []
    @Published var theme: AppTheme {
        didSet { Prefs.shared.appTheme = theme.id }
    }

    private init() {
        theme = AppTheme.fallback
        reload()
        if let same = themes.first(where: { $0.id == Prefs.shared.appTheme }) { theme = same }
    }

    var themesDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Otter/themes", isDirectory: true)
    }

    @discardableResult
    func ensureThemesDirectory() throws -> URL {
        let d = themesDirectory
        if !FileManager.default.fileExists(atPath: d.path) {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
        return d
    }

    /// 重新扫描内置 + 用户主题。用户同 id 覆盖内置。
    func reload() {
        var list = AppTheme.builtins
        var errors: [String] = []

        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL?.appendingPathComponent("themes", isDirectory: true) { dirs.append(res) }
        dirs.append(themesDirectory)

        let fm = FileManager.default
        for dir in dirs {
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where url.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: url)
                    let f = try JSONDecoder().decode(ThemeFile.self, from: data)
                    guard !f.id.isEmpty else { throw NSError(domain: "OtterTheme", code: 1) }
                    guard let accent = Color(hex: f.accent),
                          let top = Color(hex: f.backgroundTop),
                          let bottom = Color(hex: f.backgroundBottom) else {
                        throw NSError(domain: "OtterTheme", code: 2)
                    }
                    let t = AppTheme(
                        id: f.id,
                        name: f.name,
                        tagline: f.tagline ?? "",
                        isDark: f.dark ?? false,
                        accent: accent,
                        backgroundTop: top,
                        backgroundBottom: bottom,
                        sidebar: f.sidebar.flatMap { Color(hex: $0) } ?? top.opacity(0.9),
                        panel: f.panel.flatMap { Color(hex: $0) } ?? Color.white.opacity(0.1),
                        panelStroke: f.panelStroke.flatMap { Color(hex: $0) } ?? Color.white.opacity(0.15),
                        radius: CGFloat(f.radius ?? 14),
                        usesMaterial: f.material ?? false,
                        isBuiltin: false)
                    if let idx = list.firstIndex(where: { $0.id == t.id }) {
                        list[idx] = t   // 覆盖内置，便于热迭代
                    } else {
                        list.append(t)
                    }
                } catch {
                    errors.append("\(url.lastPathComponent)：\(error.localizedDescription)")
                }
            }
        }

        themes = list
        loadErrors = errors
        if let same = list.first(where: { $0.id == theme.id }) {
            if same != theme { theme = same }
        } else {
            theme = list.first ?? AppTheme.fallback
        }
    }
}