import Foundation
import Combine

/// 自定义清理规则（插件）：~/Library/Application Support/Otter/cleanrules/*.json
/// 只允许用户主目录下的路径，避免误删系统目录。
struct CleanRule: Identifiable {
    let id: String
    let name: String
    let roots: [URL]
    let children: Bool
}

private struct CleanRuleFile: Codable {
    var id: String
    var name: String
    var paths: [String]
    var children: Bool?
}

final class CleanRuleStore: ObservableObject {
    static let shared = CleanRuleStore()
    static var testDirectory: URL?

    @Published private(set) var rules: [CleanRule] = []
    @Published private(set) var loadErrors: [String] = []

    private init() { reload() }

    var rulesDirectory: URL {
        if let test = Self.testDirectory { return test }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Otter/cleanrules", isDirectory: true)
    }

    @discardableResult
    func ensureRulesDirectory() throws -> URL {
        let dir = rulesDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func reload() {
        var list: [CleanRule] = []
        var errors: [String] = []
        let fm = FileManager.default
        let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path
        let testRoot = Self.testDirectory?.path

        guard let files = try? fm.contentsOfDirectory(at: rulesDirectory, includingPropertiesForKeys: nil) else {
            rules = []
            loadErrors = []
            return
        }

        for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                let f = try JSONDecoder().decode(CleanRuleFile.self, from: data)
                guard !f.id.isEmpty, !f.name.isEmpty, !f.paths.isEmpty else {
                    throw NSError(domain: "OtterCleanRules", code: 1)
                }
                var roots: [URL] = []
                for raw in f.paths {
                    let expanded = (raw as NSString).expandingTildeInPath
                    let std = URL(fileURLWithPath: expanded).standardizedFileURL
                    let allowed = std.path == home || std.path.hasPrefix(home + "/")
                        || (testRoot != nil && std.path.hasPrefix("/tmp/otter-"))
                    guard allowed, std.path != home else {
                        throw NSError(domain: "OtterCleanRules", code: 2,
                                      userInfo: [NSLocalizedDescriptionKey: "路径必须在用户主目录下：\(raw)"])
                    }
                    roots.append(std)
                }
                list.append(CleanRule(id: f.id, name: f.name, roots: roots, children: f.children ?? true))
            } catch {
                errors.append("\(url.lastPathComponent)：\(error.localizedDescription)")
            }
        }
        rules = list
        loadErrors = errors
    }
}