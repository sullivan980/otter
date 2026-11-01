import Foundation
import Combine

/// 菜单栏显示样式（与主题、HUD 布局独立）。
/// 内置 5 种；用户可在 ~/Library/Application Support/Otter/menubar/*.json 追加或覆盖。
struct MenuBarStyle: Identifiable, Equatable {
    let id: String
    let name: String
    let showLabels: Bool
    let showIcons: Bool
    let showTrend: Bool
    let separator: String
    let isBuiltin: Bool

    static func == (lhs: MenuBarStyle, rhs: MenuBarStyle) -> Bool { lhs.id == rhs.id }

    static let value = MenuBarStyle(id: "value", name: "纯数值", showLabels: false, showIcons: false,
                                    showTrend: false, separator: " ", isBuiltin: true)
    static let label = MenuBarStyle(id: "label", name: "带名称", showLabels: true, showIcons: false,
                                    showTrend: false, separator: " ", isBuiltin: true)
    static let icon = MenuBarStyle(id: "icon", name: "图标 + 数值", showLabels: false, showIcons: true,
                                   showTrend: false, separator: " ", isBuiltin: true)
    static let dot = MenuBarStyle(id: "dot", name: "中点分隔", showLabels: false, showIcons: false,
                                  showTrend: false, separator: " · ", isBuiltin: true)
    static let trend = MenuBarStyle(id: "trend", name: "数值 + 趋势", showLabels: false, showIcons: false,
                                    showTrend: true, separator: " ", isBuiltin: true)

    static let builtins: [MenuBarStyle] = [.value, .label, .icon, .dot, .trend]
    static let fallback: MenuBarStyle = .value
}

private struct MenuBarStyleFile: Codable {
    var id: String
    var name: String
    var showLabels: Bool?
    var showIcons: Bool?
    var showTrend: Bool?
    var separator: String?
}

/// 菜单栏样式仓库：内置 + 用户 JSON；同 id 覆盖内置（改样式不用重装）。
final class MenuBarStyleStore: ObservableObject {
    static let shared = MenuBarStyleStore()

    @Published private(set) var styles: [MenuBarStyle] = MenuBarStyle.builtins
    @Published private(set) var loadErrors: [String] = []
    @Published private(set) var style: MenuBarStyle = .fallback

    private init() {
        reload()
        if let same = styles.first(where: { $0.id == Prefs.shared.menuBarStyle }) { style = same }
    }

    var stylesDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Otter/menubar", isDirectory: true)
    }

    @discardableResult
    func ensureStylesDirectory() throws -> URL {
        let dir = stylesDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func reload() {
        var list = MenuBarStyle.builtins
        var errors: [String] = []

        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL?.appendingPathComponent("menubar", isDirectory: true) { dirs.append(res) }
        dirs.append(stylesDirectory)

        let fm = FileManager.default
        for dir in dirs {
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where url.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: url)
                    let f = try JSONDecoder().decode(MenuBarStyleFile.self, from: data)
                    guard !f.id.isEmpty, !f.name.isEmpty else { throw NSError(domain: "OtterMenuBar", code: 1) }
                    let s = MenuBarStyle(id: f.id,
                                         name: f.name,
                                         showLabels: f.showLabels ?? false,
                                         showIcons: f.showIcons ?? false,
                                         showTrend: f.showTrend ?? false,
                                         separator: f.separator ?? " ",
                                         isBuiltin: false)
                    if let idx = list.firstIndex(where: { $0.id == s.id }) {
                        list[idx] = s
                    } else {
                        list.append(s)
                    }
                } catch {
                    errors.append("\(url.lastPathComponent)：\(error.localizedDescription)")
                }
            }
        }

        styles = list
        loadErrors = errors
        let before = style.id
        if let same = list.first(where: { $0.id == style.id }) {
            if same != style { style = same }
        } else if let selected = list.first(where: { $0.id == Prefs.shared.menuBarStyle }) {
            style = selected
        } else {
            style = list.first ?? MenuBarStyle.fallback
        }
        if before != style.id {
            NotificationCenter.default.post(name: ShellPrefs.changedNotification, object: nil)
        }
    }

    func select(_ id: String) {
        guard let s = styles.first(where: { $0.id == id }) else { return }
        style = s
        Prefs.shared.menuBarStyle = id
        NotificationCenter.default.post(name: ShellPrefs.changedNotification, object: nil)
    }
}