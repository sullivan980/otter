import Foundation

/// 受控提权清理：只允许 /Library/Caches 下的路径，批量交给一次管理员授权。
/// 不接收任意路径；调用方仍会再校验一次白名单与前缀。
enum PrivilegedCleaner {
    struct Result {
        var removed = 0
        var bytes: Int64 = 0
        var errors: [String] = []
    }

    static let allowedPrefix = "/Library/Caches/"

    /// 路径净化：标准化、必须位于 /Library/Caches 下、非符号链接、不在白名单。
    static func sanitize(paths: [String]) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        for raw in paths {
            let std = URL(fileURLWithPath: raw).standardizedFileURL.path
            guard std.hasPrefix(allowedPrefix), !std.contains("/../") else { continue }
            guard !WhitelistStore.shared.contains(std) else { continue }
            let url = URL(fileURLWithPath: std)
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true { continue }
            guard seen.insert(std).inserted else { continue }
            out.append(std)
        }
        return out
    }

    /// 生成提权脚本内容（单引号转义，避免路径注入）。
    static func scriptBody(for paths: [String]) -> String {
        let lines = sanitize(paths: paths).map { "rm -rf -- '" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        return "#!/bin/sh\n" + lines.joined(separator: "\n") + "\n"
    }

    static func remove(paths: [String]) -> Result {
        let safe = sanitize(paths: paths)
        guard !safe.isEmpty else { return Result() }
        var result = Result()

        let sizes: [String: Int64] = Dictionary(uniqueKeysWithValues: safe.map { p in
            (p, SpaceScanner.allocatedSize(of: URL(fileURLWithPath: p)))
        })

        let scriptPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("otter-priv-\(UUID().uuidString).sh")
        do {
            try scriptBody(for: safe).write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptPath)
        } catch {
            return Result(removed: 0, bytes: 0, errors: ["生成授权脚本失败：\(error.localizedDescription)"])
        }
        defer { try? FileManager.default.removeItem(atPath: scriptPath) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"sh '\(scriptPath)'\" with administrator privileges"]
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return Result(removed: 0, bytes: 0, errors: ["无法请求管理员权限：\(error.localizedDescription)"])
        }

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hint = msg.isEmpty ? "管理员授权被取消或失败" : msg
            return Result(removed: 0, bytes: 0, errors: [hint])
        }

        for path in safe where !FileManager.default.fileExists(atPath: path) {
            result.removed += 1
            result.bytes += sizes[path] ?? 0
        }
        if result.removed == 0 {
            result.errors.append("系统缓存未删除任何项（可能没有权限或已被清理）")
        }
        return result
    }
}
