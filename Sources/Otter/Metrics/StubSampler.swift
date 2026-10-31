import Foundation

/// 开发期占位采样器：真实采样由 Metrics 模块实现后替换。
/// 保留它可以让 UI/HUD 在采样器未就绪时也能独立开发。
final class StubSampler: MetricsSampling {
    private var t: Double = 0
    func sample() -> SystemMetrics {
        t += 2
        var m = SystemMetrics()
        m.cpuPercent = 18 + 12 * sin(t / 30)
        m.memUsedPercent = 58
        m.memTotalBytes = 16 * 1024 * 1024 * 1024
        m.memUsedBytes = UInt64(58.0 / 100 * Double(m.memTotalBytes))
        m.diskTotalBytes = 500 * 1024 * 1024 * 1024
        m.diskUsedBytes = 89 * 1024 * 1024 * 1024
        m.diskUsedPercent = 17.8
        m.downBytesPerSec = 24000
        m.upBytesPerSec = 1800
        m.coreCount = 8
        m.uptime = 3 * 86400 + 14 * 3600
        m.timestamp = Date()
        m.isReady = true
        m.topProcesses = [
            TopProcess(id: 1, name: "WindowServer", cpuPercent: 37.3, memBytes: 512 * 1024 * 1024),
            TopProcess(id: 2, name: "MenuBarAgent", cpuPercent: 11.2, memBytes: 120 * 1024 * 1024),
            TopProcess(id: 3, name: "Otter", cpuPercent: 7.0, memBytes: 60 * 1024 * 1024)
        ]
        return m
    }
}
