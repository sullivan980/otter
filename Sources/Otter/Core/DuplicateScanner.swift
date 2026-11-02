import Foundation
import CryptoKit

struct DuplicateGroup: Identifiable {
    let id: String
    let size: Int64
    let files: [String]
    var wastedBytes: Int64 { size * Int64(max(0, files.count - 1)) }
}

enum DuplicateScanner {
    static let minSize: Int64 = 1024 * 1024

    static func scan(root: URL,
                     minSize: Int64 = minSize,
                     progress: @escaping (String) -> Void,
                     isCancelled: @escaping () -> Bool,
                     completion: @escaping ([DuplicateGroup]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            guard let en = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey],
                                         options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            var bySize: [Int64: [URL]] = [:]
            var visited = 0
            for case let url as URL in en {
                if isCancelled() { break }
                visited += 1
                if visited % 500 == 0 { progress("扫描文件 \(visited)…") }
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      values.isRegularFile == true,
                      let size = values.fileSize.map(Int64.init), size >= minSize else { continue }
                bySize[size, default: []].append(url)
            }

            let candidates = bySize.filter { $0.value.count > 1 }
            progress("按大小筛选出 \(candidates.count) 组，正在比对内容…")
            var groups: [DuplicateGroup] = []
            var checked = 0
            for (size, urls) in candidates {
                if isCancelled() { break }
                checked += 1
                if checked % 10 == 0 { progress("比对内容 \(checked)/\(candidates.count)…") }
                // 先比前 4KB，再对命中的算完整哈希。
                var byQuick: [String: [URL]] = [:]
                for url in urls {
                    if let quick = hash(url: url, limit: 4096) {
                        byQuick[quick, default: []].append(url)
                    }
                }
                for (_, sameQuick) in byQuick where sameQuick.count > 1 {
                    var byFull: [String: [URL]] = [:]
                    for url in sameQuick {
                        if let full = hash(url: url, limit: nil) {
                            byFull[full, default: []].append(url)
                        }
                    }
                    for (hash, same) in byFull where same.count > 1 {
                        groups.append(DuplicateGroup(id: hash, size: size,
                                                     files: same.map { $0.path }.sorted()))
                    }
                }
            }
            let sorted = groups.sorted { $0.wastedBytes > $1.wastedBytes }
            DispatchQueue.main.async { completion(sorted) }
        }
    }

    private static func hash(url: URL, limit: Int64?) -> String? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        var hasher = SHA256()
        var remaining = limit ?? Int64.max
        while remaining > 0 {
            let want = Int(min(Int64(256 * 1024), remaining))
            guard let data = try? fh.read(upToCount: want), !data.isEmpty else { break }
            hasher.update(data: data)
            if limit != nil { remaining -= Int64(data.count) } else { remaining = Int64.max }
            if limit == nil && data.count < want { break }
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
