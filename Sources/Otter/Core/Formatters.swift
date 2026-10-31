import Foundation

enum Fmt {
    /// 百分比：不补零，整数（42% / 7% / 100%）
    static func percent(_ v: Double) -> String {
        String(format: "%.0f%%", max(0, min(100, v)))
    }

    /// 速率：紧凑单位 + /s（0B/s / 820K/s / 1.2M/s / 1.5G/s）
    static func rate(_ bytesPerSec: Double) -> String {
        let v = max(0, bytesPerSec)
        if v < 1024 { return String(format: "%.0fB/s", v) }
        if v < 1024 * 1024 { return String(format: "%.0fK/s", v / 1024) }
        if v < 1024 * 1024 * 1024 { return String(format: "%.1fM/s", v / 1024 / 1024) }
        return String(format: "%.1fG/s", v / 1024 / 1024 / 1024)
    }

    /// 容量：1.2 GB / 512 MB
    static func bytes(_ v: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = max(0, v)
        var i = 0
        while value >= 1024 && i < units.count - 1 { value /= 1024; i += 1 }
        if i == 0 { return String(format: "%.0f %@", value, units[i]) }
        return String(format: value < 10 ? "%.1f %@" : "%.0f %@", value, units[i])
    }

    /// 开机时长：3天14小时 / 5小时20分 / 12分钟
    static func uptime(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "\(d)天\(h)小时" }
        if h > 0 { return "\(h)小时\(m)分" }
        return "\(m)分钟"
    }
}
