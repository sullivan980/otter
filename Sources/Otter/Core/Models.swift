import Foundation

struct TopProcess: Identifiable, Hashable {
    let id: Int32
    let name: String
    var cpuPercent: Double
    var memBytes: UInt64
}

struct SystemMetrics {
    var cpuPercent: Double = 0
    var memUsedPercent: Double = 0
    var memUsedBytes: UInt64 = 0
    var memTotalBytes: UInt64 = 0
    var diskUsedPercent: Double = 0
    var diskUsedBytes: Int64 = 0
    var diskTotalBytes: Int64 = 0
    var upBytesPerSec: Double = 0
    var downBytesPerSec: Double = 0
    var topProcesses: [TopProcess] = []
    var uptime: TimeInterval = 0
    var coreCount: Int = 0
    var timestamp: Date = .distantPast
    var isReady: Bool = false

    static let zero = SystemMetrics()
}

protocol MetricsSampling: AnyObject {
    func sample() -> SystemMetrics
}
