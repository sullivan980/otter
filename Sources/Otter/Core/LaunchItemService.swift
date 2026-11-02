import Foundation

enum LaunchScope: String {
    case userAgent = "user"
    case systemAgent = "systemAgent"
    case systemDaemon = "systemDaemon"

    var title: String {
        switch self {
        case .userAgent: return "用户 LaunchAgents"
        case .systemAgent: return "系统 LaunchAgents"
        case .systemDaemon: return "系统 LaunchDaemons"
        }
    }
    var requiresAdmin: Bool { self != .userAgent }
}

struct LaunchItem: Identifiable {
    let id: String          // path
    let label: String
    let scope: LaunchScope
    let path: String
    let program: String
    let runAtLoad: Bool
    let keepAlive: Bool
    let disabled: Bool
    let modified: Date?
    let bytes: Int64
}

enum LaunchItemService {
    static var testDirectories: [LaunchScope: URL]?

    static func directories() -> [(LaunchScope, URL)] {
        if let test = testDirectories { return Array(test) }
        let home = NSHomeDirectory()
        return [
            (.userAgent, URL(fileURLWithPath: home + "/Library/LaunchAgents")),
            (.systemAgent, URL(fileURLWithPath: "/Library/LaunchAgents")),
            (.systemDaemon, URL(fileURLWithPath: "/Library/LaunchDaemons")),
        ]
    }

    static func scan() -> [LaunchItem] {
        var items: [LaunchItem] = []
        let fm = FileManager.default
        for (scope, dir) in directories() {
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
            else { continue }
            for url in files where url.pathExtension == "plist" {
                guard let data = try? Data(contentsOf: url),
                      let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
                else { continue }
                let label = obj["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
                let program: String = {
                    if let p = obj["Program"] as? String { return p }
                    if let args = obj["ProgramArguments"] as? [String], let first = args.first { return first }
                    if let bundleProgram = obj["BundleProgram"] as? String { return bundleProgram }
                    return "—"
                }()
                let disabled = (obj["Disabled"] as? Bool) ?? false
                let runAtLoad = (obj["RunAtLoad"] as? Bool) ?? false
                let keepAlive = (obj["KeepAlive"] as? Bool) ?? (obj["KeepAlive"] is [String: Any])
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                items.append(LaunchItem(id: url.path, label: label, scope: scope, path: url.path,
                                        program: program, runAtLoad: runAtLoad, keepAlive: keepAlive,
                                        disabled: disabled,
                                        modified: values?.contentModificationDate,
                                        bytes: Int64(values?.fileSize ?? 0)))
            }
        }
        return items.sorted { a, b in
            if a.scope != b.scope { return a.scope.rawValue < b.scope.rawValue }
            return a.label.localizedStandardCompare(b.label) == .orderedAscending
        }
    }

    /// 只允许直接修改用户 LaunchAgents；系统项需要 root，暂不提供。
    static func setDisabled(_ item: LaunchItem, disabled: Bool) -> Result<Void, Error> {
        guard item.scope == .userAgent else {
            return .failure(NSError(domain: "OtterStartup", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "系统启动项需要管理员权限，当前版本只读"]))
        }
        guard var obj = (try? Data(contentsOf: URL(fileURLWithPath: item.path)))
            .flatMap({ try? PropertyListSerialization.propertyList(from: $0, options: [], format: nil) as? [String: Any] })
        else {
            return .failure(NSError(domain: "OtterStartup", code: 2,
                                    userInfo: [NSLocalizedDescriptionKey: "无法读取 plist"]))
        }
        obj["Disabled"] = disabled
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: obj, format: .xml, options: 0)
            try data.write(to: URL(fileURLWithPath: item.path), options: .atomic)
        } catch {
            return .failure(error)
        }
        // 同步 launchd 状态；失败不阻塞（下次登录也会生效）。
        let uid = getuid()
        if disabled {
            run("/bin/launchctl", ["bootout", "gui/\(uid)", item.path])
        } else {
            run("/bin/launchctl", ["bootstrap", "gui/\(uid)", item.path])
        }
        return .success(())
    }

    private static func run(_ path: String, _ args: [String]) {
        guard FileManager.default.isExecutableFile(atPath: path) else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
    }
}