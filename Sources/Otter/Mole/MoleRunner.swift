import Foundation

/// mole 一次运行的结果（与进程退出、取消、超时解耦，方便调用方统一处理）。
struct MoleRunResult {
    /// 是否成功启动子进程。false 时其余字段无意义。
    let launched: Bool
    /// 子进程退出码；被信号杀死时为负（-1 表示未知）。
    let exitCode: Int32
    /// 是否由调用方主动取消。
    let cancelled: Bool
    /// 是否因超时被终止。
    let timedOut: Bool
    /// 合并后的 stdout + stderr 文本（最长约 4MB，超出部分截断）。
    let output: String
    /// 启动失败等错误说明。
    let errorMessage: String?
}

/// 一次可取消的 mole 运行句柄。
final class MoleTask {
    private let lock = NSLock()
    private let process: Process
    private var cancelRequested = false
    private var timeoutRequested = false

    fileprivate init(process: Process) {
        self.process = process
    }

    var isRunning: Bool {
        process.isRunning
    }

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelRequested
    }

    var isTimedOut: Bool {
        lock.lock(); defer { lock.unlock() }
        return timeoutRequested
    }

    /// 请求取消：先 SIGTERM 给 mole 自己清理的机会，3 秒仍未退出则 SIGKILL。
    func cancel() {
        lock.lock()
        cancelRequested = true
        lock.unlock()
        terminate(forceAfter: 3)
    }

    fileprivate func markTimedOutAndTerminate() {
        lock.lock()
        timeoutRequested = true
        lock.unlock()
        terminate(forceAfter: 5)
    }

    private func terminate(forceAfter seconds: TimeInterval) {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        process.terminate() // SIGTERM
        guard seconds > 0 else {
            kill(pid, SIGKILL)
            return
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + seconds) { [weak self] in
            // 只对同一进程对象再补刀：进程退出后 pid 可能被复用，isRunning 为 false 时不再操作。
            guard let self = self, self.process.isRunning, self.process.processIdentifier == pid else { return }
            kill(pid, SIGKILL)
        }
    }
}

/// mole 子进程定位与流式执行器。
///
/// 职责：
/// - 定位内置 mole（Otter.app/Contents/Resources/mole/mole），也支持源码调试/自测场景的兜底路径；
/// - 合并 stdout/stderr 流式按行回调（\n 与 \r 都切行，mole 的进度刷新也能实时看到）；
/// - 记录退出码，支持取消与超时（超时先 SIGTERM，宽限后 SIGKILL）；
/// - 输出总量有上限，防止异常输出撑大内存。
final class MoleRunner {

    static let shared = MoleRunner()

    /// 输出收集上限（4MB）：HUD/主界面只需要日志尾部与预览文本，超限即截断。
    static let maxOutputBytes: Int = 4 * 1024 * 1024

    /// 内置 mole 的相对路径（Bundle.main.resourcePath 下）。
    static let bundledRelativePath = "mole/mole"

    private let locateLock = NSLock()
    private var cachedMolePath: String?
    private var didLocate = false

    /// 找到可执行的 mole 绝对路径；找不到返回 nil。
    func locateMole() -> String? {
        locateLock.lock(); defer { locateLock.unlock() }
        if didLocate { return cachedMolePath }

        var candidates: [String] = []

        // 1) 正式 app 资源路径：Otter.app/Contents/Resources/mole/mole
        if let res = Bundle.main.resourcePath {
            candidates.append(res + "/" + Self.bundledRelativePath)
        }
        // 2) 从可执行文件位置回推 Contents/Resources（Bundle.main 异常时的兜底）
        if let exe = Bundle.main.executableURL {
            let contents = exe.deletingLastPathComponent().deletingLastPathComponent()
            candidates.append(contents.appendingPathComponent("Resources/" + Self.bundledRelativePath).path)
        }
        // 3) 源码调试/自测：在可执行文件上层目录寻找 Resources/mole/mole
        if let exe = Bundle.main.executableURL {
            var dir = exe.deletingLastPathComponent()
            for _ in 0..<4 {
                candidates.append(dir.appendingPathComponent("Resources/" + Self.bundledRelativePath).path)
                dir = dir.deletingLastPathComponent()
            }
        }
        // 4) 显式覆盖（自动验收专用）
        if let override = ProcessInfo.processInfo.environment["OTTER_MOLE_PATH"], !override.isEmpty {
            candidates.insert(override, at: 0)
        }

        let fm = FileManager.default
        for path in candidates {
            if fm.isExecutableFile(atPath: path) {
                cachedMolePath = path
                didLocate = true
                return path
            }
        }
        didLocate = true
        cachedMolePath = nil
        return nil
    }

    /// 流式运行 mole。
    ///
    /// - Parameters:
    ///   - args: 传给 mole 的参数，例如 ["clean", "--dry-run"]。
    ///   - timeout: 超时秒数；<= 0 表示不设超时。
    ///   - extraEnvironment: 额外环境变量（会覆盖继承值）。
    ///   - onLine: 每读到一行回调（在内部串行 IO 队列上调用，不占用主线程；UI 侧需自行切主线程）。
    ///   - completion: 结束时回调一次（同一 IO 队列），携带退出码与合并输出。
    @discardableResult
    func run(args: [String],
             timeout: TimeInterval = 0,
             extraEnvironment: [String: String] = [:],
             onLine: @escaping (String) -> Void,
             completion: @escaping (MoleRunResult) -> Void) -> MoleTask? {

        guard let molePath = locateMole() else {
            let message = "找不到内置 mole（\(Self.bundledRelativePath)）"
            onLine("error: " + message)
            completion(MoleRunResult(launched: false, exitCode: -1, cancelled: false, timedOut: false,
                                     output: message, errorMessage: message))
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: molePath)
        process.arguments = args

        var env = ProcessInfo.processInfo.environment
        // mole 依赖系统命令（du/df/ps/sudo 等），确保 PATH 完整；固定 UTF-8 语言避免解析歧义。
        env["PATH"] = env["PATH"].flatMap { $0.isEmpty ? nil : $0 } ?? "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        if env["LANG"] == nil || env["LANG"]!.isEmpty { env["LANG"] = "en_US.UTF-8" }
        if env["LC_ALL"] == nil || env["LC_ALL"]!.isEmpty { env["LC_ALL"] = "en_US.UTF-8" }
        for (key, value) in extraEnvironment { env[key] = value }
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        // 关闭 stdin：mole 的交互提示在没有 tty 时会走非交互分支，避免等待输入挂死。
        process.standardInput = FileHandle.nullDevice

        let task = MoleTask(process: process)
        let collector = LineCollector(onLine: onLine)
        let ioQueue = DispatchQueue(label: "com.ottermac.mole.io", qos: .utility)
        let completionGate = CompletionGate(completion)

        do {
            try process.run()
        } catch {
            let message = "mole 启动失败：\(error.localizedDescription)"
            onLine("error: " + message)
            completionGate.call(MoleRunResult(launched: false, exitCode: -1, cancelled: false, timedOut: false,
                                              output: message, errorMessage: message))
            return nil
        }

        // 父进程不再需要写端，关闭后子进程退出时读端才能收到 EOF。
        pipe.fileHandleForWriting.closeFile()

        let readHandle = pipe.fileHandleForReading
        // 收尾状态机：必须同时满足「进程已终止」与「管道 EOF」，但给 EOF 一个上限等待，
        // 避免 mole 的孙进程意外占着写端时 completion 永远不回调（UI 卡在“运行中”）。
        let stateQueue = DispatchQueue(label: "com.ottermac.mole.state")
        let drainTimeout: TimeInterval = 1.5
        var terminated = false
        var eof = false
        var finished = false

        func finalize() {
            guard !finished else { return }
            finished = true
            // 只摘掉回调，不主动 close：可能仍有回调在执行 availableData，
            // 并发关闭 fd 有崩溃风险；FileHandle 释放时会自行关闭。
            readHandle.readabilityHandler = nil
            collector.flush()
            let result = MoleRunResult(launched: true,
                                       exitCode: process.terminationStatus,
                                       cancelled: task.isCancelled,
                                       timedOut: task.isTimedOut,
                                       output: collector.text,
                                       errorMessage: nil)
            completionGate.call(result)
        }

        // 非阻塞读：数据可读 / EOF 时由系统回调，不占线程，也不会被孙进程阻塞。
        readHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                stateQueue.async {
                    eof = true
                    if terminated { finalize() }
                }
                return
            }
            collector.feed(data)
        }

        process.terminationHandler = { _ in
            stateQueue.async {
                terminated = true
                if eof {
                    finalize()
                } else {
                    stateQueue.asyncAfter(deadline: .now() + drainTimeout) { finalize() }
                }
            }
        }

        if timeout > 0 {
            ioQueue.asyncAfter(deadline: .now() + timeout) { [weak task] in
                guard let task = task, task.isRunning else { return }
                task.markTimedOutAndTerminate()
            }
        }

        return task
    }

    // MARK: - 内部工具

    /// 把字节流切成行并回调，同时累积合并文本（带 4MB 上限）。
    private final class LineCollector {
        private let queue = DispatchQueue(label: "com.ottermac.mole.collector")
        private var buffer = Data()
        private var stored = Data()
        private var truncated = false
        private let onLine: (String) -> Void

        init(onLine: @escaping (String) -> Void) {
            self.onLine = onLine
        }

        var text: String {
            queue.sync {
                var s = String(decoding: stored, as: UTF8.self)
                if truncated { s += "\n…（输出过长，已截断）" }
                return s
            }
        }

        func feed(_ chunk: Data) {
            queue.sync {
                buffer.append(chunk)
                // 同时按 \n 与 \r 切行：mole 的 spinner/进度行用 \r 刷新。
                while let index = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
                    let lineData = buffer.subdata(in: buffer.startIndex..<index)
                    buffer.removeSubrange(buffer.startIndex...index)
                    emit(lineData)
                }
                // 防御：极端情况下没有换行的超长行也会撑内存。
                if buffer.count > 64 * 1024 {
                    let lineData = buffer
                    buffer.removeAll(keepingCapacity: true)
                    emit(lineData)
                }
            }
        }

        func flush() {
            queue.sync {
                guard !buffer.isEmpty else { return }
                let lineData = buffer
                buffer.removeAll(keepingCapacity: true)
                emit(lineData)
            }
        }

        private func emit(_ data: Data) {
            guard !data.isEmpty else { return }
            let line = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return }
            if stored.count < MoleRunner.maxOutputBytes {
                let remaining = MoleRunner.maxOutputBytes - stored.count
                if data.count <= remaining {
                    stored.append(data)
                    stored.append(0x0A)
                } else {
                    stored.append(data.prefix(remaining))
                    truncated = true
                }
            } else {
                truncated = true
            }
            onLine(line)
        }
    }

    /// 保证 completion 只回调一次（避免 EOF/异常路径重复触发）。
    private final class CompletionGate {
        private let lock = NSLock()
        private var done = false
        private let completion: (MoleRunResult) -> Void

        init(_ completion: @escaping (MoleRunResult) -> Void) {
            self.completion = completion
        }

        func call(_ result: MoleRunResult) {
            lock.lock()
            if done {
                lock.unlock()
                return
            }
            done = true
            lock.unlock()
            completion(result)
        }
    }
}
