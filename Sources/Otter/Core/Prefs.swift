import Foundation

/// 轻量偏好存储（UserDefaults）。所有键集中在这里，避免散落。
final class Prefs {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    enum Key: String {
        case menuBarPreset        // minimal | dual | single | custom
        case showCPU, showMem, showDisk, showUp, showDown
        case colorByLoad          // 是否按负载着色（默认关）
        case singleMetric         // cpu | mem | disk | up | down
        case hudStyle             // n1 | n8（内置插件 id）
        case launchAtLogin
        case menuBarOrder       // CSV: cpu,mem,disk,up,down
        case notificationsEnabled
    }

    private func bool(_ k: Key, default def: Bool) -> Bool {
        guard d.object(forKey: k.rawValue) != nil else { return def }
        return d.bool(forKey: k.rawValue)
    }

    var menuBarPreset: String {
        get { d.string(forKey: Key.menuBarPreset.rawValue) ?? "dual" }
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
    var hudStyle: String {
        get { d.string(forKey: Key.hudStyle.rawValue) ?? "n1" }
        set { d.set(newValue, forKey: Key.hudStyle.rawValue) }
    }
    var launchAtLogin: Bool { get { bool(.launchAtLogin, default: false) } set { d.set(newValue, forKey: Key.launchAtLogin.rawValue) } }

    var notificationsEnabled: Bool { get { bool(.notificationsEnabled, default: true) } set { d.set(newValue, forKey: Key.notificationsEnabled.rawValue) } }

    /// 自定义菜单栏的指标顺序（CSV 存储，兼容 dev-shell/dev-ui 约定的 "menuBarOrder" 键）。
    var menuBarOrder: [String] {
        get {
            let raw = d.string(forKey: Key.menuBarOrder.rawValue) ?? "cpu,mem,disk,up,down"
            let ids = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            let valid = ids.filter { ["cpu", "mem", "disk", "up", "down"].contains($0) }
            return valid.isEmpty ? ["cpu", "mem", "disk", "up", "down"] : valid
        }
        set {
            let valid = newValue.filter { ["cpu", "mem", "disk", "up", "down"].contains($0) }
            d.set(valid.joined(separator: ","), forKey: Key.menuBarOrder.rawValue)
        }
    }
}