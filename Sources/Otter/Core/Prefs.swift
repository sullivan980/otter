import Foundation

/// 轻量偏好存储（UserDefaults）。所有键集中在这里，避免散落。
final class Prefs {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    enum Key: String {
        case menuBarPreset        // minimal | dual | single | custom
        case showCPU, showMem, showDisk, showUp, showDown
        case colorByLoad          // 是否按负载着色（默认关）
        case singleMetric         // cpu | mem | disk（保留兼容）
        case menuBarShowIcon       // 菜单栏是否显示獭图标（默认不显示）
        case menuBarStyle          // 菜单栏样式插件 id（默认 value）
        case hudStyle             // 插件 id（0.4 起默认 n2）
        case launchAtLogin
        case menuBarOrder       // CSV: cpu,mem,disk,up,down
        case notificationsEnabled
        case appTheme           // A | B | C | D | E（默认 E 水波玻璃）
        case lastCleanAt        // 上次清理时间（Unix 秒）
        case lastCleanBytes     // 上次清理释放字节数
    }

    private func bool(_ k: Key, default def: Bool) -> Bool {
        guard d.object(forKey: k.rawValue) != nil else { return def }
        return d.bool(forKey: k.rawValue)
    }

    var menuBarPreset: String {
        get { d.string(forKey: Key.menuBarPreset.rawValue) ?? "custom" }
        set { d.set(newValue, forKey: Key.menuBarPreset.rawValue) }
    }
    var showCPU: Bool { get { bool(.showCPU, default: true) } set { d.set(newValue, forKey: Key.showCPU.rawValue) } }
    var showMem: Bool { get { bool(.showMem, default: true) } set { d.set(newValue, forKey: Key.showMem.rawValue) } }
    var showDisk: Bool { get { bool(.showDisk, default: false) } set { d.set(newValue, forKey: Key.showDisk.rawValue) } }
    var showUp: Bool { get { bool(.showUp, default: false) } set { d.set(newValue, forKey: Key.showUp.rawValue) } }
    var showDown: Bool { get { bool(.showDown, default: false) } set { d.set(newValue, forKey: Key.showDown.rawValue) } }
    var colorByLoad: Bool { get { bool(.colorByLoad, default: false) } set { d.set(newValue, forKey: Key.colorByLoad.rawValue) } }
    var singleMetric: String {
        get { d.string(forKey: Key.singleMetric.rawValue) ?? "cpu" }
        set { d.set(newValue, forKey: Key.singleMetric.rawValue) }
    }
    var menuBarShowIcon: Bool { get { bool(.menuBarShowIcon, default: false) } set { d.set(newValue, forKey: Key.menuBarShowIcon.rawValue) } }
    var menuBarStyle: String {
        get { d.string(forKey: Key.menuBarStyle.rawValue) ?? "value" }
        set { d.set(newValue, forKey: Key.menuBarStyle.rawValue) }
    }

    var hudStyle: String {
        get { d.string(forKey: Key.hudStyle.rawValue) ?? "n2" }
        set { d.set(newValue, forKey: Key.hudStyle.rawValue) }
    }
    var launchAtLogin: Bool { get { bool(.launchAtLogin, default: false) } set { d.set(newValue, forKey: Key.launchAtLogin.rawValue) } }

    var notificationsEnabled: Bool { get { bool(.notificationsEnabled, default: true) } set { d.set(newValue, forKey: Key.notificationsEnabled.rawValue) } }

    /// 主题（A–E），默认 E 水波玻璃。
    var appTheme: String {
        get { d.string(forKey: Key.appTheme.rawValue) ?? "E" }
        set { d.set(newValue, forKey: Key.appTheme.rawValue) }
    }

    /// 上次成功清理的时间与释放量（用于清理页展示）。
    var lastCleanAt: Double {
        get { d.double(forKey: Key.lastCleanAt.rawValue) }
        set { d.set(newValue, forKey: Key.lastCleanAt.rawValue) }
    }
    var lastCleanBytes: Int64 {
        get { Int64(d.double(forKey: Key.lastCleanBytes.rawValue)) }
        set { d.set(Double(newValue), forKey: Key.lastCleanBytes.rawValue) }
    }

    /// 自定义菜单栏的指标顺序（CSV 存储，兼容 dev-shell/dev-ui 约定的 "menuBarOrder" 键）。
    var menuBarOrder: [String] {
        get {
            let raw = d.string(forKey: Key.menuBarOrder.rawValue) ?? "cpu,mem,disk"
            let ids = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            let valid = ids.filter { ["cpu", "mem", "disk"].contains($0) }
            return valid.isEmpty ? ["cpu", "mem", "disk"] : valid
        }
        set {
            let valid = newValue.filter { ["cpu", "mem", "disk"].contains($0) }
            d.set(valid.joined(separator: ","), forKey: Key.menuBarOrder.rawValue)
        }
    }
}