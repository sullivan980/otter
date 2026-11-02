import Foundation

struct TrashBatch: Identifiable {
    let id: String
    let date: Date
    let bytes: Int64
    let count: Int
    let items: [(original: String, stored: String)]
}

/// 应用内安全回收站：清理先移动到这里，可在设置里恢复或清空。
/// 目录：~/Library/Application Support/Otter/trash/<batchID>/
final class SafeTrashService {
    static let shared = SafeTrashService()
    static var testRoot: URL?

    private let fm = FileManager.default

    private init() {}

    var root: URL {
        if let test = Self.testRoot { return test }
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Otter/trash", isDirectory: true)
    }

    struct MoveResult {
        var batchID: String?
        var moved = 0
        var bytes: Int64 = 0
        var errors: [String] = []
    }

    func move(_ paths: [String]) -> MoveResult {
        var result = MoveResult()
        let valid = paths.filter { !WhitelistStore.shared.contains($0) }
        guard !valid.isEmpty else { return result }
        let batchID = "\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(6))"
        let dir = root.appendingPathComponent(batchID, isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            result.errors.append("创建回收站失败：\(error.localizedDescription)")
            return result
        }

        var manifest: [[String: Any]] = []
        for (idx, path) in valid.enumerated() {
            let src = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path) else { continue }
            let size = SpaceScanner.allocatedSize(of: src)
            let name = "\(idx)-\(src.lastPathComponent)"
            let dst = dir.appendingPathComponent(name)
            do {
                try fm.moveItem(at: src, to: dst)
                manifest.append(["original": path, "stored": name, "bytes": size])
                result.moved += 1
                result.bytes += size
            } catch {
                result.errors.append("\(src.lastPathComponent)：\(error.localizedDescription)")
            }
        }
        guard !manifest.isEmpty else {
            try? fm.removeItem(at: dir)
            return result
        }
        result.batchID = batchID
        let meta: [String: Any] = ["date": Date().timeIntervalSince1970, "items": manifest]
        if let data = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]) {
            try? data.write(to: dir.appendingPathComponent("manifest.json"))
        }
        return result
    }

    func list() -> [TrashBatch] {
        guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey],
                                                     options: [.skipsHiddenFiles]) else { return [] }
        return dirs.compactMap { dir -> TrashBatch? in
            let manifestURL = dir.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = obj["items"] as? [[String: Any]] else { return nil }
            let date = (obj["date"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
            let mapped = items.compactMap { item -> (String, String)? in
                guard let original = item["original"] as? String, let stored = item["stored"] as? String else { return nil }
                return (original, stored)
            }
            let bytes = items.reduce(Int64(0)) { $0 + Int64((($1["bytes"] as? NSNumber)?.int64Value) ?? 0) }
            return TrashBatch(id: dir.lastPathComponent, date: date, bytes: bytes, count: mapped.count, items: mapped)
        }.sorted { $0.date > $1.date }
    }

    func restore(all: Bool = true, batchID: String? = nil) -> (restored: Int, errors: [String]) {
        var restored = 0
        var errors: [String] = []
        for batch in list() {
            if !all, let id = batchID, batch.id != id { continue }
            let dir = root.appendingPathComponent(batch.id)
            for item in batch.items {
                let src = dir.appendingPathComponent(item.stored)
                let dst = URL(fileURLWithPath: item.original)
                guard fm.fileExists(atPath: src.path) else { continue }
                do {
                    try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if fm.fileExists(atPath: dst.path) {
                        errors.append("\(dst.lastPathComponent) 已存在，跳过")
                        continue
                    }
                    try fm.moveItem(at: src, to: dst)
                    restored += 1
                } catch {
                    errors.append("\(item.original)：\(error.localizedDescription)")
                }
            }
            if (try? fm.contentsOfDirectory(atPath: dir.path))?.count == 1 {
                try? fm.removeItem(at: dir)
            }
        }
        return (restored, errors)
    }

    func empty() -> (removed: Int, bytes: Int64, errors: [String]) {
        let batches = list()
        var removed = 0
        var bytes: Int64 = 0
        var errors: [String] = []
        for b in batches {
            do {
                try fm.removeItem(at: root.appendingPathComponent(b.id))
                removed += b.count
                bytes += b.bytes
            } catch {
                errors.append(error.localizedDescription)
            }
        }
        return (removed, bytes, errors)
    }
}
