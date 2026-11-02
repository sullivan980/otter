import Foundation

enum ReminderService {
    /// 距上次清理达到天数 → 该提醒。
    static func shouldRemindClean(lastCleanAt: Double, intervalDays: Int, now: Date = Date()) -> Bool {
        guard intervalDays > 0, lastCleanAt > 0 else { return false }
        return now.timeIntervalSince1970 - lastCleanAt >= Double(intervalDays) * 86400
    }

    /// 低磁盘提醒：超过阈值且 24h 内没提醒过。
    static func shouldRemindLowDisk(diskPercent: Double, threshold: Double, lastRemindedAt: Double, now: Date = Date()) -> Bool {
        guard diskPercent >= threshold else { return false }
        return now.timeIntervalSince1970 - lastRemindedAt >= 86400
    }

    static func check(metrics: SystemMetrics, now: Date = Date()) {
        guard Prefs.shared.notificationsEnabled else { return }
        if Prefs.shared.lowDiskReminderEnabled,
           shouldRemindLowDisk(diskPercent: metrics.diskUsedPercent,
                               threshold: Prefs.shared.alertDisk,
                               lastRemindedAt: Prefs.shared.lastLowDiskReminderAt,
                               now: now) {
            Prefs.shared.lastLowDiskReminderAt = now.timeIntervalSince1970
            Notifications.shared.post(title: "磁盘空间不足",
                                      body: "磁盘已用 \(Fmt.percent(metrics.diskUsedPercent))，建议清理。",
                                      section: "clean")
        }
        let days = Prefs.shared.cleanReminderDays
        if shouldRemindClean(lastCleanAt: Prefs.shared.lastCleanAt, intervalDays: days, now: now),
           now.timeIntervalSince1970 - Prefs.shared.lastCleanReminderAt >= Double(days) * 86400 {
            Prefs.shared.lastCleanReminderAt = now.timeIntervalSince1970
            Notifications.shared.post(title: "该清理一下了",
                                      body: "距离上次清理已超过 \(days) 天。",
                                      section: "clean")
        }
    }
}
