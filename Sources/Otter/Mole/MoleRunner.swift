import Foundation

/// mole 子进程定位 + 执行流（真实实现由 dev-data 完成）。
final class MoleRunner {
    static let shared = MoleRunner()

    /// 内置 mole 路径：Otter.app/Contents/Resources/mole/mole
    var bundledMolePath: String? {
        guard let res = Bundle.main.resourcePath else { return nil }
        let p = res + "/mole/mole"
        return FileManager.default.isExecutableFile(atPath: p) ? p : nil
    }

    func run(args: [String], onLine: @escaping (String) -> Void, completion: @escaping (Int32) -> Void) -> Process? {
        guard let mole = bundledMolePath else {
            onLine("error: 找不到内置 mole")
            completion(-1)
            return nil
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: mole)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            guard !d.isEmpty, let s = String(data: d, encoding: .utf8) else { return }
            DispatchQueue.main.async { onLine(s) }
        }
        p.terminationHandler = { proc in
            DispatchQueue.main.async { completion(proc.terminationStatus) }
        }
        do { try p.run(); return p } catch {
            onLine("error: \(error.localizedDescription)")
            completion(-1)
            return nil
        }
    }
}
