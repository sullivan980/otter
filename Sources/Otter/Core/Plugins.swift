import Foundation
import Combine

// MARK: - 插件 v1 数据模型（声明式 HUD manifest）
//
// 设计约束（与 dev-shell / lead 对齐，字段名不可改）：
//   HUDPlugin { id, name, version, author?, width?, height?, radius?, rows }
//   HUDPluginRow { metric, style, label? }
// 插件是纯声明式样式包：不含可执行代码，加载失败只报错、不影响主程序启动。

struct HUDPluginRow: Codable, Identifiable, Hashable {
    var id: String { metric + ":" + style }
    let metric: String     // cpu | mem | disk | up | down | procs | clock | uptime
    let style: String      // big | bar | ring | text | divider
    let label: String?
}

/// HUD 视觉参数（v2 插件可选）：让不写代码也能调间距/圆角/火花线/背景。
struct HUDPluginStyle: Codable, Hashable {
    var cardRadius: Double?
    var spacing: Double?
    var showSparkline: Bool?
    var background: String?   // material | solid | theme
    /// 排版预设：system（SF Pro，默认）| mono | serif | rounded。
    var typeface: String?
}

struct HUDPlugin: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let version: String
    var author: String?
    var width: Double?
    var height: Double?
    var radius: Double?
    var style: HUDPluginStyle?
    /// 布局类型：缺省为旧版 rows 布局；"stack" 为纵向堆叠模块布局。
    var layout: String?
    let rows: [HUDPluginRow]

    /// 窗口尺寸缺省值：HUD 固定 400×520（与其他窗口一致，插件可覆盖）。
    var resolvedWidth: Double { width ?? 400 }
    var resolvedHeight: Double { height ?? 520 }
    var resolvedRadius: Double { radius ?? 16 }
}

enum PluginOrigin: String {
    case builtin = "内置"
    case user = "用户"
}

enum PluginError: LocalizedError {
    case notFound
    case invalid(String)
    case alreadyInstalled(String)
    case builtinNotRemovable
    case io(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "所选路径不存在"
        case .invalid(let why): return "插件 manifest 非法：\(why)"
        case .alreadyInstalled(let id): return "已安装同 id 插件「\(id)」，可覆盖安装"
        case .builtinNotRemovable: return "内置插件不能删除"
        case .io(let why): return "文件操作失败：\(why)"
        }
    }
}

// MARK: - 插件仓库
//
// 加载顺序：内置（Bundle.main/Resources/plugins/*.json）→ 用户（~/Library/Application Support/Otter/plugins）。
// 用户插件禁止与内置同 id（否则删除/启停语义会互相覆盖）；非法 manifest 逐条记录到 loadErrors，不中断其他插件加载。
final class PluginStore: ObservableObject {
    static let shared = PluginStore()

    /// 启用/安装/删除插件后广播（HUD 可监听立即重建）。
    static let didChangeNotification = Notification.Name("OtterHUDPluginChanged")

    @Published private(set) var plugins: [HUDPlugin] = []
    /// 当前启用插件 id（同时持久化到 Prefs.hudStyle，HUD 侧按此渲染）。
    @Published var activeId: String = Prefs.shared.hudStyle {
        didSet {
            guard oldValue != activeId else { return }
            Prefs.shared.hudStyle = activeId
            NotificationCenter.default.post(name: Self.didChangeNotification,
                                            object: nil,
                                            userInfo: ["id": activeId])
        }
    }
    /// 非法/损坏 manifest 的逐条错误（设置页原样展示，不影响启动）。
    @Published private(set) var loadErrors: [String] = []
    /// 最近一次操作错误（安装/删除失败），供设置页提示。
    @Published var lastActionError: String?

    private(set) var builtinIDs: Set<String> = []
    private(set) var userIDs: Set<String> = []
    /// 被用户同 id 插件覆盖的内置插件（删掉用户覆盖后自动恢复内置）。
    private(set) var overriddenIDs: Set<String> = []

    private init() {
        reload()
    }

    // MARK: 查询

    func plugin(id: String) -> HUDPlugin? { plugins.first { $0.id == id } }

    /// HUD 侧读取入口：当前启用插件（找不到时回退第一个内置）。
    func activePlugin() -> HUDPlugin? {
        plugin(id: activeId) ?? plugins.first
    }

    func isBuiltin(_ id: String) -> Bool { builtinIDs.contains(id) && !overriddenIDs.contains(id) }

    func origin(of id: String) -> PluginOrigin {
        isBuiltin(id) ? .builtin : .user
    }

    /// 用户插件目录（不存在时返回目标路径，不自动创建）。
    var pluginsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Otter/plugins", isDirectory: true)
    }

    /// 确保用户插件目录存在（安装/打开目录前调用）。
    @discardableResult
    func ensurePluginsDirectory() throws -> URL {
        let d = pluginsDirectory
        do {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        } catch {
            throw PluginError.io(error.localizedDescription)
        }
        return d
    }

    // MARK: 加载

    func reload() {
        let fm = FileManager.default
        var errors: [String] = []
        var builtinIDs = Set<String>()
        var userIDs = Set<String>()
        var overriddenIDs = Set<String>()
        var builtinPlugins: [HUDPlugin] = []
        var userPlugins: [HUDPlugin] = []

        // 1) 内置：Bundle.main/Resources/plugins/*.json
        if let dir = Bundle.main.resourceURL?.appendingPathComponent("plugins", isDirectory: true) {
            let files = Self.jsonFiles(in: dir)
            if files.isEmpty {
                errors.append("内置插件目录为空：\(dir.path)（使用程序内置默认 manifest）")
            }
            for url in files {
                do {
                    let p = try Self.decodePlugin(at: url)
                    try Self.validate(p)
                    builtinPlugins.append(p)
                    builtinIDs.insert(p.id)
                } catch {
                    errors.append("内置插件 \(url.lastPathComponent)：\(error.localizedDescription)")
                }
            }
        } else {
            errors.append("未找到应用资源目录，使用程序内置默认 manifest")
        }

        // 内置文件缺失时用程序内置 manifest 兜底，保证 HUD 风格永远可用。
        if builtinPlugins.isEmpty {
            builtinPlugins = Self.fallbackBuiltins
            builtinIDs = Set(builtinPlugins.map { $0.id })
        }

        // 2) 用户：~/Library/Application Support/Otter/plugins
        //    - <id>/manifest.json（推荐）
        //    - 目录下散落 *.json（方便手动放）
        let userDir = pluginsDirectory
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: userDir.path, isDirectory: &isDir), isDir.boolValue {
            let children = (try? fm.contentsOfDirectory(at: userDir,
                                                        includingPropertiesForKeys: [.isDirectoryKey],
                                                        options: [.skipsHiddenFiles])) ?? []
            for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                var childIsDir: ObjCBool = false
                guard fm.fileExists(atPath: child.path, isDirectory: &childIsDir) else { continue }
                if childIsDir.boolValue {
                    let manifest = child.appendingPathComponent("manifest.json")
                    guard fm.fileExists(atPath: manifest.path) else {
                        errors.append("用户插件 \(child.lastPathComponent)：缺少 manifest.json")
                        continue
                    }
                    do {
                        let p = try Self.decodePlugin(at: manifest)
                        try Self.validate(p)
                        if builtinIDs.contains(p.id) {
                            // 同 id 覆盖内置（方便迭代内置样式）；删掉覆盖后恢复内置。
                            if let idx = builtinPlugins.firstIndex(where: { $0.id == p.id }) {
                                builtinPlugins[idx] = p
                                overriddenIDs.insert(p.id)
                            }
                        } else if userIDs.contains(p.id) {
                            errors.append("用户插件重复 id「\(p.id)」：\(child.lastPathComponent) 已忽略")
                        } else {
                            userPlugins.append(p)
                            userIDs.insert(p.id)
                        }
                    } catch {
                        errors.append("用户插件 \(child.lastPathComponent)：\(error.localizedDescription)")
                    }
                } else if child.pathExtension.lowercased() == "json" {
                    do {
                        let p = try Self.decodePlugin(at: child)
                        try Self.validate(p)
                        if builtinIDs.contains(p.id) {
                            // 同 id 覆盖内置（方便迭代内置样式）；删掉覆盖后恢复内置。
                            if let idx = builtinPlugins.firstIndex(where: { $0.id == p.id }) {
                                builtinPlugins[idx] = p
                                overriddenIDs.insert(p.id)
                            }
                        } else if userIDs.contains(p.id) {
                            errors.append("用户插件重复 id「\(p.id)」：\(child.lastPathComponent) 已忽略")
                        } else {
                            userPlugins.append(p)
                            userIDs.insert(p.id)
                        }
                    } catch {
                        errors.append("用户插件 \(child.lastPathComponent)：\(error.localizedDescription)")
                    }
                }
            }
        }

        // 内置保持文件顺序（n1 → n8），用户插件按目录名排序；同 id 已在加载阶段拒绝，不会覆盖内置。
        let merged = builtinPlugins + userPlugins

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.plugins = merged
            self.builtinIDs = builtinIDs
            self.userIDs = userIDs
            self.overriddenIDs = overriddenIDs
            self.loadErrors = errors
            if !merged.contains(where: { $0.id == self.activeId }) {
                // 当前启用插件被删除/损坏 → 回退第一个内置（0.4 起为 n2 纵向堆叠）。
                self.activeId = merged.first?.id ?? "n2"
            }
            for e in errors { NSLog("[otter] 插件加载：\(e)") }
        }
    }

    // MARK: 安装 / 删除

    /// 安装插件：url 可以是插件目录（含 manifest.json）或单个 manifest.json。
    /// - Parameter overwrite: 同 id 已安装时是否覆盖（UI 确认后传 true）。
    func install(from url: URL, overwrite: Bool = false) throws {
        lastActionError = nil
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { throw PluginError.notFound }

        var sourceDir: URL?
        let manifestURL: URL
        if isDir.boolValue {
            sourceDir = url
            manifestURL = url.appendingPathComponent("manifest.json")
        } else {
            guard url.pathExtension.lowercased() == "json" else {
                throw PluginError.invalid("请选择插件文件夹，或 manifest.json 文件")
            }
            manifestURL = url
        }
        guard fm.fileExists(atPath: manifestURL.path) else {
            throw PluginError.invalid("目录内缺少 manifest.json")
        }

        let plugin = try Self.decodePlugin(at: manifestURL)
        try Self.validate(plugin)
        // 与内置同 id 直接拒绝：否则「内置不可删 / 用户可删」语义冲突，HUD 启停也会互相覆盖。
        guard !builtinIDs.contains(plugin.id) else {
            throw PluginError.invalid("不能与内置插件同 id「\(plugin.id)」")
        }

        let target = pluginsDirectory.appendingPathComponent(plugin.id, isDirectory: true)
        if fm.fileExists(atPath: target.path) && !overwrite {
            throw PluginError.alreadyInstalled(plugin.id)
        }

        do {
            _ = try ensurePluginsDirectory()
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            if let src = sourceDir, src.standardizedFileURL != target.standardizedFileURL {
                try fm.copyItem(at: src, to: target)
            } else {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
                try fm.copyItem(at: manifestURL, to: target.appendingPathComponent("manifest.json"))
            }
        } catch {
            throw PluginError.io(error.localizedDescription)
        }

        reload()
        // 装完即启用，用户可直接在 HUD 看到效果。
        activeId = plugin.id
    }

    /// 删除用户插件；内置插件禁止删除（不报错，只记录提示）。
    func remove(id: String) {
        lastActionError = nil
        if isBuiltin(id) {
            lastActionError = PluginError.builtinNotRemovable.localizedDescription
            return
        }
        let target = pluginsDirectory.appendingPathComponent(id, isDirectory: true)
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            reload()
            if activeId == id { activeId = plugins.first?.id ?? "n2" }
        } catch {
            lastActionError = PluginError.io(error.localizedDescription).localizedDescription
        }
    }

    // MARK: 解析 / 校验

    private static func jsonFiles(in dir: URL) -> [URL] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir,
                                                     includingPropertiesForKeys: nil,
                                                     options: [.skipsHiddenFiles]) else { return [] }
        return files.filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func decodePlugin(at url: URL) throws -> HUDPlugin {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PluginError.io("读取 \(url.lastPathComponent) 失败：\(error.localizedDescription)")
        }
        do {
            return try JSONDecoder().decode(HUDPlugin.self, from: data)
        } catch {
            throw PluginError.invalid("JSON 解析失败（\(url.lastPathComponent)）：\(error.localizedDescription)")
        }
    }

    static let validMetrics: Set<String> = ["cpu", "mem", "disk", "up", "down", "procs", "clock", "uptime"]
    static let validStyles: Set<String> = ["big", "bar", "ring", "text", "divider"]

    private static func validate(_ p: HUDPlugin) throws {
        let idOK = p.id.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,47}$", options: .regularExpression) != nil
        guard idOK else { throw PluginError.invalid("id 只能包含字母/数字/._-，且 1–48 字符（当前「\(p.id)」）") }
        guard !p.name.trimmingCharacters(in: .whitespaces).isEmpty, p.name.count <= 60 else {
            throw PluginError.invalid("name 不能为空且不超过 60 字符")
        }
        guard !p.version.trimmingCharacters(in: .whitespaces).isEmpty, p.version.count <= 24 else {
            throw PluginError.invalid("version 不能为空且不超过 24 字符")
        }
        guard (1...24).contains(p.rows.count) else { throw PluginError.invalid("rows 需要 1–24 行") }
        if let w = p.width, !(200...1600).contains(w) { throw PluginError.invalid("width 需在 200–1600 之间") }
        if let h = p.height, !(200...1600).contains(h) { throw PluginError.invalid("height 需在 200–1600 之间") }
        if let r = p.radius, !(0...64).contains(r) { throw PluginError.invalid("radius 需在 0–64 之间") }
        for (i, row) in p.rows.enumerated() {
            guard validMetrics.contains(row.metric) else {
                throw PluginError.invalid("第 \(i + 1) 行 metric「\(row.metric)」不支持")
            }
            guard validStyles.contains(row.style) else {
                throw PluginError.invalid("第 \(i + 1) 行 style「\(row.style)」不支持")
            }
            if let label = row.label, label.count > 40 {
                throw PluginError.invalid("第 \(i + 1) 行 label 不超过 40 字符")
            }
        }
    }

    // MARK: 内置默认 manifest（Resources/plugins 缺失时兜底；内容与 n1.json / n8.json 一致）

    private static let fallbackBuiltins: [HUDPlugin] = [
        HUDPlugin(id: "n2", name: "N2 纵向堆叠", version: "1.0.0", author: "Otter",
                  width: 400, height: 520, radius: 18,
                  style: HUDPluginStyle(cardRadius: 13, spacing: 9, showSparkline: true, background: nil, typeface: "system"),
                  layout: "stack",
                  rows: [
                    HUDPluginRow(metric: "cpu", style: "big", label: nil),
                    HUDPluginRow(metric: "mem", style: "bar", label: nil),
                    HUDPluginRow(metric: "disk", style: "bar", label: nil),
                    HUDPluginRow(metric: "up", style: "text", label: nil),
                    HUDPluginRow(metric: "down", style: "text", label: nil),
                    HUDPluginRow(metric: "procs", style: "text", label: "TOP 进程")
                  ])
    ]}

// MARK: - 验收自测（Lead 添加，dev-ui 保留此签名）

extension PluginStore {
    /// 校验 OTTER_PLUGIN_DIR 下所有 manifest，输出 valid/rejected 供验收脚本断言。
    func selfTestJSON() -> String {
        var valid: [String] = []
        var rejected: [String] = []
        let dir = ProcessInfo.processInfo.environment["OTTER_PLUGIN_DIR"]
        let fm = FileManager.default
        if let dir = dir, let files = try? fm.contentsOfDirectory(atPath: dir) {
            for f in files.sorted() where f.hasSuffix(".json") {
                let path = dir + "/" + f
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path))
                    let p = try JSONDecoder().decode(HUDPlugin.self, from: data)
                    guard !p.id.isEmpty, !p.rows.isEmpty else { throw PluginError.invalid("id/rows 不能为空") }
                    valid.append(p.id)
                } catch {
                    let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    rejected.append("{\"file\":\"" + f + "\",\"error\":\"" + msg.replacingOccurrences(of: "\"", with: "'") + "\"}")
                }
            }
        }
        let validJSON = valid.map { "\"" + $0 + "\"" }.joined(separator: ",")
        let rejectedJSON = rejected.joined(separator: ",")
        return "{\"mode\":\"plugins\",\"valid\":[" + validJSON + "],\"rejected\":[" + rejectedJSON + "]}"
    }
}