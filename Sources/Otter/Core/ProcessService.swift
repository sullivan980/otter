import Foundation
import Darwin

enum ProcessService {
    enum KillError: LocalizedError {
        case failed(String)
        var errorDescription: String? {
            switch self {
            case .failed(let message): return message
            }
        }
    }

    static func terminate(pid: Int32, force: Bool) -> Result<Void, Error> {
        guard pid > 1 else {
            return .failure(KillError.failed("拒绝操作系统进程"))
        }
        let signal = force ? SIGKILL : SIGTERM
        if kill(pid, signal) == 0 {
            return .success(())
        }
        return .failure(KillError.failed(String(cString: strerror(errno))))
    }
}
