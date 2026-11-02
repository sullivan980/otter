import Foundation

struct AlertEvent: Equatable {
    let kind: String
    let title: String
    let body: String
}

/// 阈值告警：指标连续超过阈值 N 秒才发通知，冷却期内不重复。
final class AlertMonitor {
    static let shared = AlertMonitor()

    private var since: [String: Date] = [:]
    private var lastFired: [String: Date] = [:]

    private init() {}

    func reset() {
        since.removeAll()
        lastFired.removeAll()
    }

    @discardableResult
    func evaluate(_ m: SystemMetrics, now: Date = Date()) -> [AlertEvent] {
        guard m.isReady else { return [] }
        var events: [AlertEvent] = []
        let duration = Prefs.shared.alertDuration
        let cooldown = Prefs.shared.alertCooldown
        let checks: [(String, Double, Double, String, String)] = [
            ("cpu", m.cpuPercent, Prefs.shared.alertCPU, "CPU 持续偏高", "CPU 已持续高于 \(Int(Prefs.shared.alertCPU))%"),
            ("mem", m.memUsedPercent, Prefs.shared.alertMem, "内存持续偏高", "内存已持续高于 \(Int(Prefs.shared.alertMem))%"),
            ("disk", m.diskUsedPercent, Prefs.shared.alertDisk, "磁盘空间不足", "磁盘占用已高于 \(Int(Prefs.shared.alertDisk))%"),
        ]
        for (id, value, threshold, title, bodyPrefix) in checks {
            if value >= threshold {
                if since[id] == nil { since[id] = now }
                if let start = since[id], now.timeIntervalSince(start) >= duration {
                    if let last = lastFired[id], now.timeIntervalSince(last) < cooldown { continue }
                    lastFired[id] = now
                    let body = "\(bodyPrefix)（当前 \(Fmt.percent(value))）"
                    events.append(AlertEvent(kind: id, title: title, body: body))
                }
            } else {
                since[id] = nil
            }
        }
        return events
    }
}
