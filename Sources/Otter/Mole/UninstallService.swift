import Foundation

/// 卸载服务错误。
enum UninstallServiceError: LocalizedError {
    case appNotFound(String)
    case noAppsFound
    case unsafePath(String)
    case nothingTrashed([String])

    var errorDescription: String? {
        switch self {
        case .appNotFound(let path):
            return "应用不存在：\(path)"
        case .noAppsFound:
            return "没有找到可卸载的应用"
        case .unsafePath(let path):
            return "拒绝操作不安全路径：\(path)"
        case .nothingTrashed(let reasons):
            if reasons.isEmpty { return "没有要移入废纸篓的内容" }
            return "移入废纸篓失败：\(reasons.prefix(3).joined(separator: "；"))"
        }
    }
}

/// 卸载服务：枚举应用、扫描常规关联残留、把勾选项移入废纸篓。
///
/// 设计要点：
/// - 应用列表来自 /Applications 与 ~/Applications（只看顶层，不递归）；
/// - bundleId 用 Bundle/Info.plist 读取，不依赖 plutil 子进程；
/// - 残留只查约定俗成的 ~/Library 位置（Caches / Preferences / Application Support /
///   Logs / Saved Application State / WebKit / HTTPStorages / Containers / Group Containers），
///   不做全盘扫描；
/// - 回收站使用 FileManager.trashItem（不调用 Finder、不需要自动化权限，可找回）；
/// - 有路径安全护栏：拒绝根目录、系统目录、家目录、~/Library 本身等危险目标；
/// - 所有文件系统操作在后台串行队列执行，回调默认投递主队列。
final class UninstallService: UninstallServicing {

    /// 回调投递队列。UI 场景保持默认主队列。
    var callbackQueue: DispatchQueue = .main

    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.ottermac.uninstall.io", qos: .userInitiated)

    /// 残留候选目录（相对 ~/Library）。
    private static let leftoverRoots = [
        "Caches", "Preferences", "Application Support", "Logs",
        "Saved Application State", "WebKit", "HTTPStorages", "Containers", "Group Containers"
    ]

    // MARK: - UninstallServicing

    func listApps(completion: @escaping (Result<[AppItem], Error>) -> Void) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let apps = self.enumerateApps()
            self.deliver { completion(.success(apps)) }
        }
    }

    func scan(_ app: AppItem, completion: @escaping (Result<UninstallScan, Error>) -> Void) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let scan = try self.buildScan(app)
                self.deliver { completion(.success(scan)) }
            } catch {
                self.deliver { completion(.failure(error)) }
            }
        }
    }

    func trash(_ items: [LeftoverItem], completion: @escaping (Result<Int, Error>) -> Void) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            guard !items.isEmpty else {
                self.deliver { completion(.success(0)) }
                return
            }

            var trashed = 0
            var failures: [String] = []
            for item in items {
                guard self.isSafeTrashPath(item.path) else {
                    failures.append("拒绝不安全路径：\(item.path)")
                    continue
                }
                let url = URL(fileURLWithPath: item.path)
                guard self.fileManager.fileExists(atPath: item.path) else {
                    failures.append("不存在：\(item.path)")
                    continue
                }
                do {
                    try self.fileManager.trashItem(at: url, resultingItemURL: nil)
                    trashed += 1
                } catch {
                    failures.append("\(item.path)：\(error.localizedDescription)")
                }
            }

            if trashed == 0 {
                self.deliver { completion(.failure(UninstallServiceError.nothingTrashed(failures))) }
            } else {
                self.deliver { completion(.success(trashed)) }
            }
        }
    }

    // MARK: - 应用枚举

    private func enumerateApps() -> [AppItem] {
        let home = NSHomeDirectory()
        let directories = ["/Applications", home + "/Applications"]
        var seen = Set<String>()
        var apps: [AppItem] = []

        for directory in directories {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            guard let children = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else { continue }

            for child in children {
                guard child.pathExtension == "app" else { continue }
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                // 解析 .app 需要目录（软链接指过去的也允许，Path 保留链接本身）。
                guard values?.isDirectory == true else { continue }
                let path = child.resolvingSymlinksInPath().path
                guard seen.insert(path).inserted else { continue }
                let name = child.deletingPathExtension().lastPathComponent
                apps.append(AppItem(id: path,
                                    name: name,
                                    path: path,
                                    bundleId: self.bundleId(of: child)))
            }
        }

        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return apps
    }

    /// 读取 bundleId：优先 Bundle（能正确处理二进制 plist 与本地化），失败再直接解析 Info.plist。
    private func bundleId(of appURL: URL) -> String? {
        if let bundle = Bundle(url: appURL), let identifier = bundle.bundleIdentifier, !identifier.isEmpty {
            return identifier
        }
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any],
              let identifier = dictionary["CFBundleIdentifier"] as? String,
              !identifier.isEmpty else { return nil }
        return identifier
    }

    // MARK: - 残留扫描

    private func buildScan(_ app: AppItem) throws -> UninstallScan {
        guard fileManager.fileExists(atPath: app.path) else {
            throw UninstallServiceError.appNotFound(app.path)
        }

        let home = NSHomeDirectory()
        let library = home + "/Library"
        let appFileName = (app.path as NSString).lastPathComponent
        let appName = appFileName.hasSuffix(".app") ? String(appFileName.dropLast(4)) : appFileName
        let bundleId = app.bundleId ?? self.bundleId(of: URL(fileURLWithPath: app.path))

        var candidates: [(path: String, kind: String, label: String)] = []
        candidates.append((app.path, "app", "应用本体"))

        // 按应用名和 bundleId 两套约定查找残留在旧版里是并列的，这里同样都查。
        func add(_ path: String, _ kind: String, _ label: String) {
            candidates.append((path, kind, label))
        }
        add("\(library)/Caches/\(appName)", "cache", "缓存")
        add("\(library)/Logs/\(appName)", "logs", "日志")
        add("\(library)/Application Support/\(appName)", "data", "应用数据")
        add("\(library)/Preferences/\(appName).plist", "prefs", "偏好设置")

        if let bundleId = bundleId, !bundleId.isEmpty {
            add("\(library)/Caches/\(bundleId)", "cache", "缓存")
            add("\(library)/Preferences/\(bundleId).plist", "prefs", "偏好设置")
            add("\(library)/Application Support/\(bundleId)", "data", "应用数据")
            add("\(library)/WebKit/\(bundleId)", "data", "网络存储")
            add("\(library)/HTTPStorages/\(bundleId)", "data", "网络存储")
            add("\(library)/Saved Application State/\(bundleId).savedState", "state", "窗口状态")
            add("\(library)/Containers/\(bundleId)", "data", "沙盒数据")
            add("\(library)/Group Containers/group.\(bundleId)", "data", "共享容器")
        }

        var items: [LeftoverItem] = []
        var seen = Set<String>()
        for candidate in candidates {
            let standardized = (candidate.path as NSString).standardizingPath
            guard fileManager.fileExists(atPath: standardized) else { continue }
            guard seen.insert(standardized).inserted else { continue }
            let bytes = directorySize(at: URL(fileURLWithPath: standardized))
            items.append(LeftoverItem(id: standardized,
                                      path: standardized,
                                      kind: candidate.kind,
                                      bytes: bytes))
        }

        // 应用本体固定置顶，其余按大小降序，UI 一眼看到大头。
        if let appIndex = items.firstIndex(where: { $0.kind == "app" }), appIndex != 0 {
            let appItem = items.remove(at: appIndex)
            items.insert(appItem, at: 0)
        }
        if items.count > 1 {
            let head = items[0]
            let tail = items.dropFirst().sorted { $0.bytes > $1.bytes }
            items = [head] + tail
        }

        return UninstallScan(app: app, leftovers: items)
    }

    /// 递归统计路径占用（块分配大小优先，取不到则退回逻辑大小；不跟随符号链接、不重复计算）。
    private func directorySize(at url: URL) -> Int64 {
        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey
        ]

        let values = try? url.resourceValues(forKeys: Set(resourceKeys))
        if values?.isRegularFile == true {
            return fileBytes(values)
        }
        guard values?.isDirectory == true else {
            return fileBytes(values)
        }

        var total: Int64 = 0
        guard let enumerator = fileManager.enumerator(at: url,
                                                      includingPropertiesForKeys: resourceKeys,
                                                      options: [],
                                                      errorHandler: { _, _ in true }) else {
            return 0
        }
        for case let fileURL as URL in enumerator {
            guard let fileValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)) else { continue }
            if fileValues.isSymbolicLink == true { continue }
            if fileValues.isDirectory == true { continue }
            total += fileBytes(fileValues)
        }
        return total
    }

    private func fileBytes(_ values: URLResourceValues?) -> Int64 {
        guard let values = values else { return 0 }
        if let allocated = values.totalFileAllocatedSize { return Int64(allocated) }
        if let allocated = values.fileAllocatedSize { return Int64(allocated) }
        if let size = values.fileSize { return Int64(size) }
        return 0
    }

    // MARK: - 安全护栏

    /// 只允许把用户可见的应用与用户库内容移入废纸篓；拒绝根、系统目录、家目录、~/Library 等危险目标。
    private func isSafeTrashPath(_ rawPath: String) -> Bool {
        let path = (rawPath as NSString).standardizingPath
        guard path.hasPrefix("/"), path != "/", !path.isEmpty else { return false }
        guard !rawPath.contains("\u{0}") else { return false }

        let home = NSHomeDirectory()
        let forbiddenExact: Set<String> = [
            "/", "/Applications", "/Library", "/System", "/Users", "/Volumes",
            "/usr", "/bin", "/sbin", "/private", "/opt", "/etc", "/var",
            home, home + "/Library", home + "/Applications", home + "/Desktop",
            home + "/Documents", home + "/Downloads", home + "/Movies",
            home + "/Music", home + "/Pictures", home + "/Public"
        ]
        if forbiddenExact.contains(path) { return false }

        let forbiddenPrefixes = ["/System/", "/Library/", "/usr/", "/bin/", "/sbin/",
                                 "/private/", "/etc/", "/var/", "/dev/", "/Volumes/"]
        for prefix in forbiddenPrefixes where path.hasPrefix(prefix) {
            return false
        }
        if path == home + "/Library" { return false }

        // 目标必须真实存在（不存在由 trash 流程报错，避免空路径猜测）。
        return true
    }

    // MARK: - 回调投递

    private func deliver(_ block: @escaping () -> Void) {
        callbackQueue.async(execute: block)
    }
}
