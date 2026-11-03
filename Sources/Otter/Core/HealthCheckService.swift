import Foundation

struct HealthIssue: Identifiable {
    enum Severity: Int { case info = 1, warning = 2, critical = 3 }
    let id: String
    let title: String
    let detail: String
    let severity: Severity
    let bytes: Int64
    let section: String
    let actionTitle: String
}

struct HealthReport {
    var score = 100
    var issues: [HealthIssue] = []
    var checkedAt = Date()
    var cleanableBytes: Int64 = 0
    var trashBytes: Int64 = 0
    var largeFiles: [(path: String, bytes: Int64)] = []
    var startupCount = 0
    var diskFreePercent: Double = 0
    var batteryHealth: Double?
}

enum HealthCheckService {
    static func scan(progress: @escaping (String) -> Void,
                     completion: @escaping (HealthReport) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var r = HealthReport()
            let fm = FileManager.default

            progress("检查磁盘空间…")
            if let attrs = try? fm.attributesOfFileSystem(forPath: "/"),
               let free = attrs[.systemFreeSize] as? NSNumber,
               let total = attrs[.systemSize] as? NSNumber, total.int64Value > 0 {
                r.diskFreePercent = Double(free.int64Value) / Double(total.int64Value) * 100
            }

            progress("扫描可清理缓存…")
            let cleanSem = DispatchSemaphore(value: 0)
            let cleanService = NativeCleanService()
            cleanService.callbackQueue = DispatchQueue(label: "otter.health.clean")
            cleanService.preview(onLine: { _ in }, completion: { result in
                if case .success(let plan) = result {
                    r.cleanableBytes = plan.categories.filter { $0.id != "system_caches" }
                        .reduce(0) { $0 + $1.items.reduce(0) { $0 + $1.bytes } }
                }
                cleanSem.signal()
            })
            _ = cleanSem.wait(timeout: .now() + 20)

            progress("统计废纸篓…")
            let trashPath = NSHomeDirectory() + "/.Trash"
            r.trashBytes = SpaceScanner.allocatedSize(of: URL(fileURLWithPath: trashPath))
            r.trashBytes += SafeTrashService.shared.list().reduce(0) { $0 + $1.bytes }

            progress("扫描大文件…")
            r.largeFiles = findLargeFiles(root: URL(fileURLWithPath: NSHomeDirectory()),
                                          minSize: 500 * 1024 * 1024,
                                          maxFiles: 20)

            progress("检查启动项…")
            r.startupCount = LaunchItemService.scan().filter { $0.scope == .userAgent }.count
            r.batteryHealth = BatteryService.read().healthPercent

            progress("生成报告…")
            r.issues = buildIssues(r)
            r.score = score(for: r.issues)
            DispatchQueue.main.async { completion(r) }
        }
    }

    static func score(for issues: [HealthIssue]) -> Int {
        var s = 100
        for issue in issues {
            switch issue.id {
            case "disk": s -= 30
            case "clean": s -= min(20, 8 + Int(issue.bytes / (2 * 1024 * 1024 * 1024)) * 2)
            case "trash": s -= 8
            case "large": s -= 6
            case "startup": s -= 5
            case "stale": s -= 5
            case "battery": s -= 5
            default: s -= 2
            }
        }
        return max(0, min(100, s))
    }

    private static func buildIssues(_ r: HealthReport) -> [HealthIssue] {
        var issues: [HealthIssue] = []
        if r.diskFreePercent < 10 {
            issues.append(HealthIssue(id: "disk", title: L("磁盘空间不足", "Low disk space"),
                                      detail: L("可用空间仅 \(String(format: "%.0f", r.diskFreePercent))%。建议先清理缓存和废纸篓。",
                                                "Only \(String(format: "%.0f", r.diskFreePercent))% free. Clean caches and Trash first."),
                                      severity: .critical, bytes: 0, section: "clean",
                                      actionTitle: L("去清理", "Clean")))
        }
        if r.cleanableBytes > 500 * 1024 * 1024 {
            issues.append(HealthIssue(id: "clean", title: L("可清理缓存", "Cleanable caches"),
                                      detail: L("扫描到可安全清理的缓存/日志，预计 \(Fmt.bytes(Double(r.cleanableBytes)))。",
                                                "\(Fmt.bytes(Double(r.cleanableBytes))) of caches and logs can be cleaned safely."),
                                      severity: .warning, bytes: r.cleanableBytes, section: "clean",
                                      actionTitle: L("去清理", "Clean")))
        }
        if r.trashBytes > 200 * 1024 * 1024 {
            issues.append(HealthIssue(id: "trash", title: L("废纸篓可以清空", "Trash can be emptied"),
                                      detail: L("废纸篓 + Otter 回收站共 \(Fmt.bytes(Double(r.trashBytes)))。",
                                                "\(Fmt.bytes(Double(r.trashBytes))) in Trash and Otter Trash."),
                                      severity: .warning, bytes: r.trashBytes, section: "clean",
                                      actionTitle: L("去处理", "Open")))
        }
        if !r.largeFiles.isEmpty {
            let total = r.largeFiles.reduce(Int64(0)) { $0 + $1.bytes }
            issues.append(HealthIssue(id: "large", title: L("发现大文件", "Large files found"),
                                      detail: L("\(r.largeFiles.count) 个超过 500MB 的文件，共 \(Fmt.bytes(Double(total)))。",
                                                "\(r.largeFiles.count) files over 500MB, \(Fmt.bytes(Double(total))) total."),
                                      severity: .info, bytes: total, section: "disk",
                                      actionTitle: L("去查看", "View")))
        }
        if r.startupCount > 8 {
            issues.append(HealthIssue(id: "startup", title: L("启动项较多", "Many startup items"),
                                      detail: L("用户 LaunchAgents 有 \(r.startupCount) 项，可检查是否有不用的。",
                                                "\(r.startupCount) user LaunchAgents. Check for unused ones."),
                                      severity: .info, bytes: 0, section: "startup",
                                      actionTitle: L("去查看", "View")))
        }
        let last = Prefs.shared.lastCleanAt
        if last > 0, Date().timeIntervalSince1970 - last > 30 * 86400 {
            issues.append(HealthIssue(id: "stale", title: L("很久没有清理", "No cleanup recently"),
                                      detail: L("距离上次清理已超过 30 天。", "It has been over 30 days since the last cleanup."),
                                      severity: .info, bytes: 0, section: "clean",
                                      actionTitle: L("去清理", "Clean")))
        }
        if let health = r.batteryHealth, health < 80 {
            issues.append(HealthIssue(id: "battery", title: L("电池健康偏低", "Battery health is low"),
                                      detail: L("电池健康度 \(String(format: "%.0f", health))%，属于正常老化，不影响清理。",
                                                "Battery health \(String(format: "%.0f", health))%. Normal aging; cleaning is unaffected."),
                                      severity: .info, bytes: 0, section: "maintenance",
                                      actionTitle: L("查看", "View")))
        }
        return issues.sorted { $0.severity.rawValue > $1.severity.rawValue }
    }

    private static func findLargeFiles(root: URL, minSize: Int64, maxFiles: Int) -> [(path: String, bytes: Int64)] {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: root,
                                     includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey],
                                     options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var found: [(String, Int64)] = []
        var visited = 0
        for case let url as URL in en {
            visited += 1
            if visited > 80_000 { break }
            guard let v = try? url.resourceValues(forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey]),
                  v.isRegularFile == true else { continue }
            let size = Int64(v.totalFileAllocatedSize ?? 0)
            if size >= minSize {
                found.append((url.path, size))
                if found.count >= maxFiles { break }
            }
        }
        return found.sorted { $0.1 > $1.1 }
    }
}
