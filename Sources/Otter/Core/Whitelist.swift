import Foundation
import Combine

/// 清理保护路径（白名单）：installer / 项目产物扫描时跳过这些路径。
/// 存储：~/Library/Application Support/Otter/whitelist.json
final class WhitelistStore: ObservableObject {
    static let shared = WhitelistStore()

    @Published private(set) var paths: [String] = []

    private init() { reload() }

    var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Otter/whitelist.json")
    }

    func reload() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([String].self, from: data) else {
            paths = []
            return
        }
        paths = list
    }

    private func persist() {
        let fm = FileManager.default
        try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(paths) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    @discardableResult
    func add(_ path: String) -> Bool {
        let p = Self.normalize(path)
        guard !p.isEmpty, !contains(p) else { return false }
        paths.append(p)
        paths.sort()
        persist()
        return true
    }

    func remove(_ path: String) {
        paths.removeAll { $0 == path }
        persist()
    }

    func contains(_ path: String) -> Bool {
        let p = Self.normalize(path)
        return paths.contains { root in
            p == root || p.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
    }

    static func normalize(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }
}