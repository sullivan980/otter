import Foundation
import Darwin

/// 系统维护只读诊断（不执行 DNS/Spotlight 等有风险操作）。
struct MaintenanceReport {
    var osVersion = ""
    var arch = ""
    var model = ""
    var uptime: TimeInterval = 0
    var volumeName = ""
    var isSSD: Bool?
    var smartStatus: String?
    var freeBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var spotlight = "未知"
    var snapshotCount = 0
    var userAgents = 0
    var systemAgents = 0
    var systemDaemons = 0
    var errors: [String] = []
}

enum MaintenanceService {
    static func collect() -> MaintenanceReport {
        var r = MaintenanceReport()
        let p = ProcessInfo.processInfo
        r.osVersion = p.operatingSystemVersionString
        r.arch = p.machineHardwareName ?? "?"
        r.model = sysctl("hw.model") ?? "Mac"
        r.uptime = p.systemUptime

        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let free = attrs[.systemFreeSize] as? NSNumber,
           let total = attrs[.systemSize] as? NSNumber {
            r.freeBytes = free.int64Value
            r.totalBytes = total.int64Value
        }

        if let plist = diskInfoPlist() {
            r.volumeName = plist["VolumeName"] as? String ?? ""
            r.isSSD = plist["SolidState"] as? Bool
            if let smart = plist["SMARTStatus"] as? String, !smart.isEmpty {
                r.smartStatus = smart
            }
        }

        if let out = run("/usr/bin/mdutil", ["-s", "/"]) {
            if out.lowercased().contains("indexing enabled") { r.spotlight = "已启用" }
            else if out.lowercased().contains("indexing disabled") { r.spotlight = "已关闭" }
            else if out.lowercased().contains("error") { r.spotlight = "读取失败" }
        } else {
            r.spotlight = "不可读"
        }

        if let out = run("/usr/bin/tmutil", ["listlocalsnapshots", "/"]) {
            r.snapshotCount = out.split(separator: "\n").filter { $0.contains("com.apple.TimeMachine") }.count
        }

        let home = NSHomeDirectory()
        r.userAgents = countPlist(in: home + "/Library/LaunchAgents")
        r.systemAgents = countPlist(in: "/Library/LaunchAgents")
        r.systemDaemons = countPlist(in: "/Library/LaunchDaemons")
        return r
    }

    static func sysctl(_ name: String) -> String? {
        run("/usr/sbin/sysctl", ["-n", name])?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func countPlist(in dir: String) -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return 0 }
        return files.filter { $0.hasSuffix(".plist") }.count
    }

    private static func diskInfoPlist() -> [String: Any]? {
        guard let out = run("/usr/sbin/diskutil", ["info", "-plist", "/"]),
              let data = out.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        else { return nil }
        return plist as? [String: Any]
    }

    private static func run(_ path: String, _ args: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
        } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

private extension ProcessInfo {
    var machineHardwareName: String? {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
}