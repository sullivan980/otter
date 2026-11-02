import Foundation

/// 清理服务错误。
enum CleanServiceError: LocalizedError {
    case busy
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .busy: return "已有清理任务在运行，请等待完成或先取消"
        case .cancelled: return "已取消清理"
        case .failed(let message): return message
        }
    }
}

/// 原生清理服务（阶段 2）：只处理用户级安全目录，支持按勾选项执行。
/// 不调用 mole；系统级缓存暂不包含（后续阶段补 sudo helper）。
final class NativeCleanService: CleanServicing {
    var callbackQueue: DispatchQueue = .main

    private let lock = NSLock()
    private var cancelled = false
    private var running = false

    static var testRootOverride: String?
    static var testRulesOnly = false

    private struct Spec {
        let id: String
        let title: String
        let roots: [URL]
        let children: Bool   // true: 清理 root 下每一项；false: 清理 root 本身
        var requiresRoot: Bool = false
    }

    private func specs() -> [Spec] {
        if let root = Self.testRootOverride {
            return [Spec(id: "test", title: "测试缓存", roots: [URL(fileURLWithPath: root)], children: true)]
        }
        var pluginSpecs: [Spec] = CleanRuleStore.shared.rules.map { rule in
            Spec(id: "plugin:\(rule.id)", title: rule.name, roots: rule.roots, children: rule.children)
        }
        if Self.testRulesOnly { return pluginSpecs }

        let home = NSHomeDirectory()
        func u(_ p: String) -> URL { URL(fileURLWithPath: p.replacingOccurrences(of: "~", with: home)) }
        let builtins = [
            Spec(id: "user_caches", title: "用户缓存", roots: [u("~/Library/Caches")], children: true),
            Spec(id: "user_logs", title: "用户日志", roots: [u("~/Library/Logs")], children: true),
            Spec(id: "trash", title: "废纸篓", roots: [u("~/.Trash")], children: true),
            Spec(id: "xcode", title: "Xcode 缓存", roots: [
                u("~/Library/Developer/Xcode/DerivedData"),
                u("~/Library/Developer/CoreSimulator/Caches"),
            ], children: false),
            Spec(id: "dev_caches", title: "开发缓存", roots: [
                u("~/.npm/_cacache"),
                u("~/.gradle/caches"),
            ], children: false),
            Spec(id: "system_caches", title: "系统缓存（需授权）",
                 roots: [URL(fileURLWithPath: "/Library/Caches")], children: true, requiresRoot: true),
        ]
        return builtins + pluginSpecs
    }

    // MARK: - 预览

    func preview(onLine: @escaping (String) -> Void, completion: @escaping (Result<CleanPlan, Error>) -> Void) {
        guard begin() else { deliver { completion(.failure(CleanServiceError.busy)) }; return }
        cancelled = false
        let fm = FileManager.default
        let specs = self.specs()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var categories: [CleanCategory] = []
            let whitelist = WhitelistStore.shared
            for spec in specs {
                if self.isCancelled() { break }
                self.deliver { onLine("扫描 \(spec.title)…") }
                var items: [CleanItem] = []
                var total: Int64 = 0
                for root in spec.roots {
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else { continue }
                    let targets: [URL]
                    if spec.children {
                        targets = ((try? fm.contentsOfDirectory(at: root,
                                                                 includingPropertiesForKeys: nil,
                                                                 options: [.skipsHiddenFiles])) ?? [])
                    } else {
                        targets = [root]
                    }
                    for url in targets.prefix(120) {
                        if whitelist.contains(url.path) { continue }
                        let bytes = SpaceScanner.allocatedSize(of: url)
                        guard bytes > 0 else { continue }
                        items.append(CleanItem(id: url.path, label: url.lastPathComponent, bytes: bytes))
                        total += bytes
                    }
                }
                items.sort { $0.bytes > $1.bytes }
                categories.append(CleanCategory(id: spec.id, title: spec.title, bytes: total, items: items))
            }
            self.end()
            let raw = categories.map { "➤ \($0.title) \($0.bytes)" }.joined(separator: "\n")
            let plan = CleanPlan(categories: categories,
                                 potentialBytes: categories.reduce(0) { $0 + $1.bytes },
                                 summaryItems: categories.reduce(0) { $0 + $1.items.count },
                                 rawText: raw)
            self.deliver { completion(.success(plan)) }
        }
    }

    // MARK: - 执行

    func run(onProgress: @escaping (CleanProgress) -> Void, completion: @escaping (Result<CleanResult, Error>) -> Void) {
        run(selected: [], onProgress: onProgress, completion: completion)
    }

    func run(selected: Set<String>, onProgress: @escaping (CleanProgress) -> Void, completion: @escaping (Result<CleanResult, Error>) -> Void) {
        guard begin() else { deliver { completion(.failure(CleanServiceError.busy)) }; return }
        cancelled = false
        let paths = selected.compactMap { key -> String? in
            guard let idx = key.firstIndex(of: "|") else { return nil }
            return String(key[key.index(after: idx)...])
        }
        let allowedRoots = specs().flatMap { $0.roots.map { $0.standardizedFileURL.path } }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            var freed: Int64 = 0
            var removed = 0
            var errors: [String] = []
            var lines: [String] = []

            let targets = paths.filter { p in
                let std = URL(fileURLWithPath: p).standardizedFileURL.path
                let inRoot = allowedRoots.contains { std == $0 || std.hasPrefix($0 + "/") }
                return inRoot && !WhitelistStore.shared.contains(std)
            }
            let systemPrefix = "/Library/Caches"
            let systemPaths = targets.filter { $0 == systemPrefix || $0.hasPrefix(systemPrefix + "/") }
            let normalPaths = targets.filter { !systemPaths.contains($0) }

            for path in normalPaths {
                if self.isCancelled() { break }
                let url = URL(fileURLWithPath: path)
                let bytes = SpaceScanner.allocatedSize(of: url)
                do {
                    try fm.removeItem(at: url)
                    freed += bytes
                    removed += 1
                    lines.append("删除 \(path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))（\(Fmt.bytes(Double(bytes)))）")
                } catch {
                    errors.append("\(url.lastPathComponent)：\(error.localizedDescription)")
                }
                self.deliver { onProgress(CleanProgress(phase: "清理中 \(removed)/\(targets.count)", line: errors.last ?? lines.last ?? "")) }
            }

            if !systemPaths.isEmpty && !self.isCancelled() {
                self.deliver { onProgress(CleanProgress(phase: "请求管理员权限…", line: "")) }
                let privileged = PrivilegedCleaner.remove(paths: systemPaths)
                freed += privileged.bytes
                removed += privileged.removed
                errors.append(contentsOf: privileged.errors)
                lines.append("系统缓存：删除 \(privileged.removed) 项（\(Fmt.bytes(Double(privileged.bytes)))）")
            }

            self.end()
            let success = errors.isEmpty
            let output = (lines + errors.map { "失败：" + $0 }).joined(separator: "\n")
            self.deliver {
                completion(.success(CleanResult(success: success, freedBytes: freed, output: output)))
            }
            if !success {
                self.deliver { onProgress(CleanProgress(phase: "完成（\(errors.count) 项失败）", line: "")) }
            }
        }
    }

    func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
    }

    // MARK: - 状态

    private func begin() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if running { return false }
        running = true
        return true
    }

    private func end() {
        lock.lock(); running = false; lock.unlock()
    }

    private func isCancelled() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    private func deliver(_ block: @escaping () -> Void) {
        callbackQueue.async(execute: block)
    }
}