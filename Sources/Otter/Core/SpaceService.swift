import Foundation

// MARK: - 空间清理：安装包 / 项目构建产物（原生实现，不依赖 mole）

struct InstallerItem: Identifiable, Hashable {
    let id: String
    let path: String
    let name: String
    let bytes: Int64
    let modified: Date?
}

struct ArtifactItem: Identifiable, Hashable {
    let id: String
    let path: String
    let name: String
    let project: String
    let bytes: Int64
    let modified: Date?
}

enum SpaceScanMode: String, CaseIterable, Identifiable {
    case installers, projects
    var id: String { rawValue }
    var title: String { self == .installers ? "安装包" : "项目产物" }
    var subtitle: String {
        self == .installers
            ? "扫描下载目录里的 .dmg / .pkg / .iso / .xip，移到废纸篓。"
            : "扫描常见构建产物（node_modules / build / target / DerivedData 等），7 天以上才列入。"
    }
    var systemImage: String { self == .installers ? "shippingbox" : "hammer" }
}

enum SpaceScanner {
    static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "iso", "xip"]
    static let artifactNames: Set<String> = [
        "node_modules", "build", "target", "dist", ".next", ".nuxt", ".output",
        "DerivedData", ".build", "Pods", "coverage", ".turbo", ".parcel-cache", "out"
    ]
    /// build/dist/out 太通用，必须旁边有工程文件才认，避免把 Maven 仓库里的 data/build 当产物。
    static let ambiguousArtifacts: Set<String> = ["build", "dist", "out"]
    static let projectMarkers: Set<String> = [
        "package.json", "build.gradle", "build.gradle.kts", "settings.gradle",
        "Cargo.toml", "pyproject.toml", "setup.py", "pubspec.yaml", "CMakeLists.txt", "Package.swift"
    ]

    static var defaultProjectRoots: [URL] {
        ["~/Code", "~/Projects", "~/Developer", "~/Documents"].map {
            URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath)
        }
    }

    static var installerRoots: [URL] {
        let candidates = [
            "~/Downloads",
            "~/Library/Downloads",
            "/Users/Shared/Downloads",
            "~/Library/Mobile Documents/com~apple~CloudDocs/Downloads",
            "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
            "~/Downloads/Telegram Desktop",
        ]
        return candidates.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
    }

    // MARK: 扫描

    static func scanInstallers() -> [InstallerItem] {
        let fm = FileManager.default
        var seen = Set<String>()
        var out: [InstallerItem] = []
        for root in installerRoots {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
                                          .fileSizeKey, .contentModificationDateKey, .isSymbolicLinkKey]
            guard let en = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { continue }
            var depthGuard = 0
            while let url = en.nextObject() as? URL {
                depthGuard += 1
                if depthGuard > 400 { break }
                guard url.path.hasPrefix(root.path) else { continue }
                let rel = String(url.path.dropFirst(root.path.count)).split(separator: "/")
                if rel.count > 2 { en.skipDescendants(); continue }
                let ext = url.pathExtension.lowercased()
                guard installerExtensions.contains(ext) else { continue }
                let values = try? url.resourceValues(forKeys: Set(keys))
                guard values?.isRegularFile == true else { continue }
                if WhitelistStore.shared.contains(url.path) { continue }
                let p = url.standardizedFileURL.path
                guard seen.insert(p).inserted else { continue }
                let bytes = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
                // 云端未下载（逻辑大小 > 0、实际占用 0）不列进来：删了也释放不出空间。
                if bytes == 0, (values?.fileSize ?? 0) > 0 { continue }
                out.append(InstallerItem(id: p, path: p, name: url.lastPathComponent, bytes: bytes,
                                         modified: values?.contentModificationDate))
            }
        }
        return out.sorted { $0.bytes > $1.bytes }
    }

    static func scanProjects(roots: [URL]? = nil, minAgeDays: Int = 7) -> [ArtifactItem] {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-Double(minAgeDays) * 86400)
        let searchRoots = (roots ?? defaultProjectRoots).filter {
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: $0.path, isDirectory: &isDir) && isDir.boolValue
        }
        var out: [ArtifactItem] = []
        for root in searchRoots {
            let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey,
                                          .contentModificationDateKey, .totalFileAllocatedSizeKey]
            guard let en = fm.enumerator(at: root,
                                         includingPropertiesForKeys: keys,
                                         options: [.skipsPackageDescendants],
                                         errorHandler: { _, _ in true }) else { continue }
            var depthGuard = 0
            while let url = en.nextObject() as? URL {
                depthGuard += 1
                if depthGuard > 60_000 { break }
                let components = url.pathComponents.count - root.pathComponents.count
                guard components > 0 else { continue }
                if components > 7 { en.skipDescendants(); continue }
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard isDir else { continue }
                let name = url.lastPathComponent
                if name.hasPrefix(".") && !artifactNames.contains(name) {
                    en.skipDescendants()
                    continue
                }
                guard artifactNames.contains(name) else { continue }
                if WhitelistStore.shared.contains(url.path) {
                    en.skipDescendants()
                    continue
                }
                // 跳过隐藏目录下的通用产物（如 ~/.m2repo/.../data/build）。
                let rel = url.pathComponents.dropFirst(root.pathComponents.count)
                if rel.dropLast().contains(where: { $0.hasPrefix(".") }) {
                    en.skipDescendants()
                    continue
                }
                if ambiguousArtifacts.contains(name), !hasProjectMarker(around: url) {
                    en.skipDescendants()
                    continue
                }
                let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let mod = mod, mod > cutoff {
                    en.skipDescendants()
                    continue
                }
                let size = allocatedSize(of: url)
                let project = url.deletingLastPathComponent().lastPathComponent
                out.append(ArtifactItem(id: url.path, path: url.path, name: name, project: project,
                                        bytes: size, modified: mod))
                en.skipDescendants()
                if out.count >= 300 { break }
            }
        }
        return out.sorted { $0.bytes > $1.bytes }
    }

    /// 向上找 1–2 层工程标记文件（package.json / *.xcodeproj 等）。
    private static func hasProjectMarker(around url: URL) -> Bool {
        let fm = FileManager.default
        var dir = url.deletingLastPathComponent()
        for _ in 0..<2 {
            if let names = try? fm.contentsOfDirectory(atPath: dir.path) {
                for n in names {
                    if projectMarkers.contains(n) || n.hasSuffix(".xcodeproj") || n.hasSuffix(".xcworkspace") {
                        return true
                    }
                }
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return false
    }

    static func allocatedSize(of url: URL) -> Int64 {
        var total: Int64 = 0
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
                                      .isSymbolicLinkKey]
        guard let en = FileManager.default.enumerator(at: url,
                                                      includingPropertiesForKeys: keys,
                                                      options: [],
                                                      errorHandler: { _, _ in true }) else { return 0 }
        while let item = en.nextObject() as? URL {
            let v = try? item.resourceValues(forKeys: Set(keys))
            if v?.isSymbolicLink == true { en.skipDescendants(); continue }
            guard v?.isRegularFile == true else { continue }
            total += Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
        }
        return total
    }

    // MARK: 删除（确认后直接删除；白名单路径一律跳过）

    struct DeleteResult {
        var removed = 0
        var bytes: Int64 = 0
        var errors: [String] = []
    }

    static func delete(paths: [String]) -> DeleteResult {
        var result = DeleteResult()
        for path in paths {
            guard !WhitelistStore.shared.contains(path) else { continue }
            let url = URL(fileURLWithPath: path)
            let size = allocatedSize(of: url)
            do {
                try FileManager.default.removeItem(at: url)
                result.removed += 1
                result.bytes += Int64(size)
            } catch {
                result.errors.append("\(url.lastPathComponent)：\(error.localizedDescription)")
            }
        }
        return result
    }

    private static func itemSize(_ url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
    }

    // MARK: 自测

    static func selfTestJSON() -> String {
        let fm = FileManager.default
        let root = "/tmp/otter-space-fixture"
        try? fm.removeItem(atPath: root)
        try? fm.createDirectory(atPath: root + "/Downloads", withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: root + "/project/node_modules", withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: root + "/project/build", withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: root + "/project/target", withIntermediateDirectories: true)
        fm.createFile(atPath: root + "/Downloads/a.dmg", contents: Data(count: 1_000_000))
        fm.createFile(atPath: root + "/Downloads/b.pkg", contents: Data(count: 1_000_000))
        fm.createFile(atPath: root + "/project/node_modules/x.bin", contents: Data(count: 500_000))
        fm.createFile(atPath: root + "/project/build/y.bin", contents: Data(count: 500_000))
        fm.createFile(atPath: root + "/project/target/z.bin", contents: Data(count: 500_000))
        let old = Date().addingTimeInterval(-10 * 86400)
        for dir in [root + "/project/node_modules", root + "/project/build", root + "/project/target"] {
            try? fm.setAttributes([.modificationDate: old], ofItemAtPath: dir)
        }
        let buildPath = root + "/project/build"
        let whitelist = WhitelistStore.shared
        whitelist.add(buildPath)
        defer { whitelist.remove(WhitelistStore.normalize(buildPath)) }

        let installers = scanInstallersForTest(folder: root + "/Downloads")
        let projects = scanProjects(roots: [URL(fileURLWithPath: root + "/project")])
        let del = delete(paths: installers.map { $0.path })
        let dmgGone = !fm.fileExists(atPath: root + "/Downloads/a.dmg")
        let buildKept = fm.fileExists(atPath: buildPath)
        let ok = installers.count == 2 && projects.count == 2 && del.removed == 2 && dmgGone && buildKept
        let err = del.errors.joined(separator: " | ").replacingOccurrences(of: "\"", with: "'")
        return "{\"mode\":\"space-fixture\",\"installers\":\(installers.count),\"projects\":\(projects.count),\"deleted\":\(del.removed),\"buildKept\":\(buildKept),\"errors\":\"\(err)\",\"ok\":\(ok)}"
    }

    /// 自测专用：从指定目录扫安装包（避免扫真实下载目录）。
    static func scanInstallersForTest(folder: String) -> [InstallerItem] {
        let url = URL(fileURLWithPath: folder)
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
                                      .contentModificationDateKey]
        guard let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: []) else { return [] }
        var out: [InstallerItem] = []
        while let item = en.nextObject() as? URL {
            guard installerExtensions.contains(item.pathExtension.lowercased()) else { continue }
            let v = try? item.resourceValues(forKeys: Set(keys))
            guard v?.isRegularFile == true else { continue }
            out.append(InstallerItem(id: item.path, path: item.path, name: item.lastPathComponent,
                                     bytes: Int64(v?.totalFileAllocatedSize ?? 0),
                                     modified: v?.contentModificationDate))
        }
        return out
    }
}