import Foundation

/// 轻量内存日志（不落盘），供诊断报告导出。
final class OtterLog {
    static let shared = OtterLog()
    private let lock = NSLock()
    private var buffer: [String] = []
    private let maxLines = 500

    private init() {}

    func add(_ message: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let line = "[\(f.string(from: Date()))] \(message)"
        lock.lock()
        buffer.append(line)
        if buffer.count > maxLines { buffer.removeFirst(buffer.count - maxLines) }
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return buffer
    }
}
