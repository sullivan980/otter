import Foundation

struct SensorReport {
    var gpuPercent: Double?
    var gpuInUseBytes: Int64?
    var gpuAllocBytes: Int64?
    var thermalState = "正常"
    var temperatureC: Double?     // Apple Silicon 需要特权 SMC，当前通常不可用
    var lowPowerMode = false
}

enum SensorService {
    static func read() -> SensorReport {
        var r = SensorReport()
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: r.thermalState = "正常"
        case .fair: r.thermalState = "偏热"
        case .serious: r.thermalState = "严重"
        case .critical: r.thermalState = "临界"
        @unknown default: r.thermalState = "未知"
        }
        r.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        guard let out = run("/usr/sbin/ioreg", ["-r", "-c", "IOAccelerator", "-d", "1"]) else { return r }
        func value(_ key: String) -> Int64? {
            guard let range = out.range(of: "\"\(key)\"=") else { return nil }
            let rest = out[range.upperBound...]
            let digits = rest.prefix { $0.isNumber }
            return Int64(digits)
        }
        if let util = value("Device Utilization %") { r.gpuPercent = Double(util) }
        r.gpuInUseBytes = value("In use system memory")
        r.gpuAllocBytes = value("Alloc system memory")
        return r
    }

    private static func run(_ path: String, _ args: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return nil }
        return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}
