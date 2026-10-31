import Foundation

/// 菜单栏标题格式化（纯函数，供 UI 与验收自测共用）。
/// 规范：百分比不补零；速率带单位；模块间单空格；顺序按用户设置。
enum MenuBarFormat {
    static func plainTitle(ids: [String], metrics m: SystemMetrics, order: [String]) -> String {
        let sequence = order.filter { ids.contains($0) } + ids.filter { !order.contains($0) }
        var parts: [String] = []
        for id in sequence {
            switch id {
            case "cpu": parts.append(Fmt.percent(m.cpuPercent))
            case "mem": parts.append(Fmt.percent(m.memUsedPercent))
            case "disk": parts.append(Fmt.percent(m.diskUsedPercent))
            case "up": parts.append("↑" + Fmt.rate(m.upBytesPerSec))
            case "down": parts.append("↓" + Fmt.rate(m.downBytesPerSec))
            default: break
            }
        }
        return parts.isEmpty ? "Otter" : parts.joined(separator: " ")
    }

    /// 验收自测：边界值与格式断言用的样例。
    static func selfTestJSON() -> String {
        var normal = SystemMetrics.zero
        normal.cpuPercent = 42.4; normal.memUsedPercent = 61.2
        normal.diskUsedPercent = 17.8
        normal.upBytesPerSec = 1.5 * 1024 * 1024 * 1024
        normal.downBytesPerSec = 820 * 1024

        let zero = SystemMetrics.zero
        var full = SystemMetrics.zero
        full.cpuPercent = 100; full.memUsedPercent = 100; full.diskUsedPercent = 100

        let dual = plainTitle(ids: ["cpu", "mem"], metrics: normal, order: ["cpu", "mem", "disk", "up", "down"])
        let zeroTitle = plainTitle(ids: ["cpu", "mem"], metrics: zero, order: ["cpu", "mem", "disk", "up", "down"])
        let fullTitle = plainTitle(ids: ["cpu", "mem"], metrics: full, order: ["cpu", "mem", "disk", "up", "down"])
        let net = plainTitle(ids: ["up", "down"], metrics: normal, order: ["cpu", "mem", "disk", "up", "down"])
        let reordered = plainTitle(ids: ["cpu", "mem"], metrics: normal, order: ["mem", "cpu", "disk", "up", "down"])
        let empty = plainTitle(ids: [], metrics: normal, order: [])

        return String(
            format: "{\"mode\":\"menubar\",\"dual\":\"%@\",\"zero\":\"%@\",\"full\":\"%@\",\"net\":\"%@\",\"reordered\":\"%@\",\"empty\":\"%@\"}",
            dual, zeroTitle, fullTitle, net, reordered, empty)
    }
}