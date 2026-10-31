import Foundation
import Combine

/// 插件 v1（声明式 HUD manifest）。字段见 docs/SPEC.md。
struct HUDPluginRow: Codable, Identifiable, Hashable {
    var id: String { metric + ":" + style }
    let metric: String     // cpu | mem | disk | up | down | procs | clock | uptime
    let style: String      // big | bar | ring | text | divider
    let label: String?
}

struct HUDPlugin: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let version: String
    var author: String?
    var width: Double?
    var height: Double?
    var radius: Double?
    let rows: [HUDPluginRow]
}

/// 插件加载/安装（dev-ui 实现）。内置 n1/n8 从 Resources/plugins 读取。
final class PluginStore: ObservableObject {
    static let shared = PluginStore()

    @Published private(set) var plugins: [HUDPlugin] = []
    @Published var activeId: String = Prefs.shared.hudStyle

    private init() {}

    func plugin(id: String) -> HUDPlugin? { plugins.first { $0.id == id } }

    // 以下由 dev-ui 实现
    func reload() {}
    func install(from url: URL) throws {}
    func remove(id: String) {}
}
