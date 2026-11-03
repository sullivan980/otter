import Foundation

/// 下载后的自动安装：挂载 DMG → 校验版本/签名 → 暂存 → 退出后由 helper 替换并重启。
enum UpdateInstaller {
    enum InstallError: LocalizedError {
        case attachFailed(String)
        case appMissing
        case versionMismatch(expected: String, actual: String)
        case wrongBundle
        case copyFailed(String)
        case noPermission
        case helperFailed(String)

        var errorDescription: String? {
            switch self {
            case .attachFailed(let m): return "挂载 DMG 失败：\(m)"
            case .appMissing: return "DMG 里没有 Otter.app"
            case .versionMismatch(let e, let a): return "版本不匹配（期望 \(e)，实际 \(a)）"
            case .wrongBundle: return "DMG 内的应用不是 Otter"
            case .copyFailed(let m): return "复制应用失败：\(m)"
            case .noPermission: return "没有写入 /Applications 的权限"
            case .helperFailed(let m): return "启动安装 helper 失败：\(m)"
            }
        }
    }

    static var testTargetApp: URL?
    static var testWaitPID: Int32?
    static var testLaunchAfter = true

    /// 只允许从 GitHub 域名自动安装，避免任意地址替换应用。
    static func isTrustedDMG(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host == "github.com" || host == "objects.githubusercontent.com"
            || host == "raw.githubusercontent.com" || host == "github-releases.githubusercontent.com"
    }

    static func installDownloaded(dmgURL: URL, expectedVersion: String,
                                  completion: @escaping (Result<Void, Error>) -> Void) {
        let isLocalFile = dmgURL.isFileURL
        guard isLocalFile || isTrustedDMG(dmgURL) else {
            completion(.failure(InstallError.attachFailed("下载地址不在允许的 GitHub 域名内")))
            return
        }
        guard FileManager.default.fileExists(atPath: dmgURL.path) else {
            completion(.failure(InstallError.attachFailed("下载文件不存在：\(dmgURL.path)")))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let mount: String
            do {
                mount = try attach(dmgURL)
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            defer { detach(mount) }

            let app = URL(fileURLWithPath: mount).appendingPathComponent("Otter.app")
            guard FileManager.default.fileExists(atPath: app.path) else {
                DispatchQueue.main.async { completion(.failure(InstallError.appMissing)) }
                return
            }
            guard bundleIdentifier(app) == "com.ottermac.app" else {
                DispatchQueue.main.async { completion(.failure(InstallError.wrongBundle)) }
                return
            }
            let actual = version(app)
            guard actual == expectedVersion else {
                DispatchQueue.main.async {
                    completion(.failure(InstallError.versionMismatch(expected: expectedVersion, actual: actual)))
                }
                return
            }
            // 结构校验（ad-hoc 签名也应通过）。
            if let verify = run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path]), verify.status != 0 {
                DispatchQueue.main.async {
                    completion(.failure(InstallError.copyFailed("签名校验失败：\(verify.output)")))
                }
                return
            }

            let target = testTargetApp ?? Bundle.main.bundleURL
            let parent = target.deletingLastPathComponent()
            guard FileManager.default.isWritableFile(atPath: parent.path) else {
                DispatchQueue.main.async { completion(.failure(InstallError.noPermission)) }
                return
            }
            let stagingRoot = parent.appendingPathComponent(".OtterUpdate-\(UUID().uuidString.prefix(8))")
            let staged = stagingRoot.appendingPathComponent("Otter.app")
            do {
                try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
                let ditto = run("/usr/bin/ditto", [app.path, staged.path])
                guard ditto?.status == 0 else {
                    throw InstallError.copyFailed(ditto?.output ?? "ditto 失败")
                }
                try replace(stagedApp: staged, targetApp: target,
                            expectedVersion: expectedVersion,
                            waitPID: testWaitPID ?? ProcessInfo.processInfo.processIdentifier,
                            launchAfter: testTargetApp == nil ? true : testLaunchAfter,
                            completion: completion)
                return
            } catch {
                try? FileManager.default.removeItem(at: stagingRoot)
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// 供 UI/测试复用：生成并启动退出后替换的 helper。
    static func replace(stagedApp: URL, targetApp: URL, expectedVersion: String,
                        waitPID: Int32, launchAfter: Bool,
                        completion: @escaping (Result<Void, Error>) -> Void) throws {
        guard version(stagedApp) == expectedVersion else {
            throw InstallError.versionMismatch(expected: expectedVersion, actual: version(stagedApp))
        }
        func quote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let script = """
        #!/bin/sh
        PID=\(waitPID)
        TARGET=\(quote(targetApp.path))
        STAGED=\(quote(stagedApp.path))
        while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
        rm -rf "$TARGET"
        mv "$STAGED" "$TARGET" || exit 1
        rmdir "$(dirname "$STAGED")" 2>/dev/null || true
        xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
        \(launchAfter ? "open \"$TARGET\"" : "exit 0")
        """
        let scriptPath = NSTemporaryDirectory() + "otter-update-\(UUID().uuidString.prefix(8)).sh"
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptPath)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = [scriptPath]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        completion(.success(()))
    }

    // MARK: helpers

    private static func attach(_ dmg: URL) throws -> String {
        guard let result = run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly"]) else {
            throw InstallError.attachFailed("无法运行 hdiutil")
        }
        guard result.status == 0 else {
            throw InstallError.attachFailed(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        for line in result.output.split(separator: "\n") {
            if let range = line.range(of: "/Volumes/") {
                return String(line[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        throw InstallError.attachFailed("未找到挂载点")
    }

    private static func detach(_ mount: String) {
        _ = run("/usr/bin/hdiutil", ["detach", mount, "-force"])
    }

    private static func bundleIdentifier(_ app: URL) -> String? {
        plist(app)?["CFBundleIdentifier"] as? String
    }

    private static func version(_ app: URL) -> String {
        (plist(app)?["CFBundleShortVersionString"] as? String) ?? "?"
    }

    private static func plist(_ app: URL) -> [String: Any]? {
        let url = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        else { return nil }
        return obj as? [String: Any]
    }

    private static func run(_ path: String, _ args: [String]) -> (status: Int32, output: String)? {
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run(); p.waitUntilExit() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}