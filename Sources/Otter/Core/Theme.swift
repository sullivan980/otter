import SwiftUI

/// 五套主题（A–E）。默认 E 水波玻璃。
/// 设计稿：mockups/theme-proposals.html（同一套 token 贯穿菜单栏/HUD/主界面/引导）。
enum AppTheme: String, CaseIterable, Identifiable {
    case riverMist = "A"
    case onsen = "B"
    case deepDive = "C"
    case paperOtter = "D"
    case liquidGlass = "E"

    var id: String { rawValue }
    static let fallback: AppTheme = .liquidGlass

    var name: String {
        switch self {
        case .riverMist: return "河岸晨雾"
        case .onsen: return "温泉汤屋"
        case .deepDive: return "深潜"
        case .paperOtter: return "纸水獭"
        case .liquidGlass: return "水波玻璃"
        }
    }

    var tagline: String {
        switch self {
        case .riverMist: return "淡水青蓝 · 安静干净"
        case .onsen: return "米白陶土 · 蒸汽柔光"
        case .deepDive: return "深海荧色 · 夜间低刺激"
        case .paperOtter: return "米纸墨线 · 手账感"
        case .liquidGlass: return "液态玻璃 · 最系统原生"
        }
    }

    var isDark: Bool { self == .deepDive || self == .liquidGlass }

    /// 主操作色（按钮/选中态/强调）。
    var accent: Color {
        switch self {
        case .riverMist: return Color(red: 0.18, green: 0.49, blue: 0.56)
        case .onsen: return Color(red: 0.75, green: 0.42, blue: 0.25)
        case .deepDive: return Color(red: 0.31, green: 0.82, blue: 0.77)
        case .paperOtter: return Color(red: 0.25, green: 0.42, blue: 0.35)
        case .liquidGlass: return Color(red: 0.43, green: 0.83, blue: 0.91)
        }
    }

    /// 背景渐变。
    var backgroundTop: Color {
        switch self {
        case .riverMist: return Color(red: 0.95, green: 0.97, blue: 0.97)
        case .onsen: return Color(red: 0.98, green: 0.94, blue: 0.89)
        case .deepDive: return Color(red: 0.04, green: 0.13, blue: 0.16)
        case .paperOtter: return Color(red: 0.95, green: 0.93, blue: 0.88)
        case .liquidGlass: return Color(red: 0.05, green: 0.13, blue: 0.20)
        }
    }
    var backgroundBottom: Color {
        switch self {
        case .riverMist: return Color(red: 0.85, green: 0.91, blue: 0.93)
        case .onsen: return Color(red: 0.94, green: 0.85, blue: 0.75)
        case .deepDive: return Color(red: 0.02, green: 0.08, blue: 0.10)
        case .paperOtter: return Color(red: 0.90, green: 0.87, blue: 0.80)
        case .liquidGlass: return Color(red: 0.03, green: 0.09, blue: 0.13)
        }
    }

    var sidebar: Color {
        switch self {
        case .riverMist: return Color(red: 0.94, green: 0.97, blue: 0.97)
        case .onsen: return Color(red: 0.97, green: 0.92, blue: 0.86)
        case .deepDive: return Color(red: 0.03, green: 0.10, blue: 0.13)
        case .paperOtter: return Color(red: 0.95, green: 0.93, blue: 0.88)
        case .liquidGlass: return Color.white.opacity(0.05)
        }
    }

    var panel: Color {
        switch self {
        case .riverMist: return Color.white.opacity(0.72)
        case .onsen: return Color(red: 1.0, green: 0.98, blue: 0.95).opacity(0.92)
        case .deepDive: return Color(red: 0.05, green: 0.15, blue: 0.18)
        case .paperOtter: return Color(red: 0.98, green: 0.97, blue: 0.94)
        case .liquidGlass: return Color.white.opacity(0.09)
        }
    }

    var panelStroke: Color {
        switch self {
        case .riverMist: return Color.black.opacity(0.06)
        case .onsen: return Color.black.opacity(0.08)
        case .deepDive: return Color(red: 0.43, green: 0.91, blue: 0.86).opacity(0.16)
        case .paperOtter: return Color.black.opacity(0.22)
        case .liquidGlass: return Color.white.opacity(0.16)
        }
    }

    var radius: CGFloat {
        switch self {
        case .riverMist: return 14
        case .onsen: return 18
        case .deepDive: return 14
        case .paperOtter: return 6
        case .liquidGlass: return 18
        }
    }

    /// 是否使用系统毛玻璃材质（玻璃/晨雾更通透；纸/温泉/深潜用实色更稳）。
    var usesMaterial: Bool { self == .liquidGlass || self == .riverMist }

    var swatches: [Color] {
        switch self {
        case .riverMist: return [Color(red: 0.95, green: 0.97, blue: 0.97), Color(red: 0.85, green: 0.91, blue: 0.93), accent]
        case .onsen: return [Color(red: 0.98, green: 0.94, blue: 0.89), Color(red: 0.94, green: 0.85, blue: 0.75), accent]
        case .deepDive: return [Color(red: 0.04, green: 0.13, blue: 0.16), Color(red: 0.02, green: 0.08, blue: 0.10), accent]
        case .paperOtter: return [Color(red: 0.95, green: 0.93, blue: 0.88), Color(red: 0.98, green: 0.97, blue: 0.94), accent]
        case .liquidGlass: return [Color(red: 0.05, green: 0.13, blue: 0.20), Color(red: 0.03, green: 0.09, blue: 0.13), accent]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// 主题状态（持久化到 Prefs.appTheme，默认 E）。
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published var theme: AppTheme {
        didSet { Prefs.shared.appTheme = theme.rawValue }
    }

    private init() {
        theme = AppTheme(rawValue: Prefs.shared.appTheme) ?? AppTheme.fallback
    }
}
