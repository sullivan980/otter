import Foundation

/// 诊断报告：版本 / 系统 / 指标 / 偏好 / 插件状态 / 最近日志 / 崩溃报告列表。
/// 只写入用户桌面（失败则临时目录），不上传任何数据。
enum DiagnosticsService {
    static func text(metrics: SystemMetrics?, state: AppState?) -> String {
        let p = ProcessInfo.processInfo
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let m = MaintenanceService.collect()
        var lines: [String] = []
        lines.append("Otter 诊断报告")
        lines.append("生成时间: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("版本: \(version) (\(build))")
        lines.append("系统: \(m.osVersion) / \(m.arch) / \(m.model)")
        lines.append("已运行: \(Fmt.uptime(m.uptime))")
        lines.append("磁盘: 可用 \(Fmt.bytes(Double(m.freeBytes))) / \(Fmt.bytes(Double(m.totalBytes)))")
        lines.append("")
        lines.append("## 指标")
        if let metrics = metrics, metrics.isReady {
            lines.append("CPU: \(Fmt.percent(metrics.cpuPercent))  内存: \(Fmt.percent(metrics.memUsedPercent))  磁盘: \(Fmt.percent(metrics.diskUsedPercent))")
            lines.append("上传: \(Fmt.rate(metrics.upBytesPerSec))  下载: \(Fmt.rate(metrics.downBytesPerSec))")
            lines.append("核心: \(metrics.coreCount)  进程样本: \(metrics.topProcesses.count)")
        } else {
            lines.append("指标未就绪")
        }
        lines.append("")
        lines.append("## 偏好")
        lines.append("主题: \(Prefs.shared.appTheme)  HUD: \(Prefs.shared.hudStyle)  菜单栏样式: \(Prefs.shared.menuBarStyle)")
        lines.append("菜单栏图标: \(Prefs.shared.menuBarShowIcon ? "显示" : "隐藏")")
        lines.append("通知: \(Prefs.shared.notificationsEnabled ? "开" : "关")  登录启动: \(Prefs.shared.launchAtLogin ? "开" : "关")")
        lines.append("白名单: \(WhitelistStore.shared.paths.count) 条  清理规则: \(CleanRuleStore.shared.rules.count) 条")
        lines.append("")
        lines.append("## 插件")
        for e in PluginStore.shared.loadErrors { lines.append("HUD: \(e)") }
        for e in CleanRuleStore.shared.loadErrors { lines.append("清理规则: \(e)") }
        for e in MenuBarStyleStore.shared.loadErrors { lines.append("菜单栏: \(e)") }
        lines.append("内置 HUD 插件: \(PluginStore.shared.plugins.map { $0.id }.joined(separator: ", "))")
        lines.append("")
        lines.append("## 最近日志（最多 100 行）")
        lines.append(contentsOf: OtterLog.shared.snapshot().suffix(100))
        lines.append("")
        lines.append("## 崩溃报告（~/Library/Logs/DiagnosticReports）")
        let crashes = crashReports()
        if crashes.isEmpty {
            lines.append("无 Otter 相关崩溃报告")
        } else {
            lines.append(contentsOf: crashes)
        }
        return lines.joined(separator: "\n")
    }

    static func crashReports(limit: Int = 8) -> [String] {
        let dir = NSHomeDirectory() + "/Library/Logs/DiagnosticReports"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return files.filter { $0.localizedCaseInsensitiveContains("Otter") }
            .sorted()
            .suffix(limit)
            .map { name in
                let path = dir + "/" + name
                let date = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil
                return "\(name)  \(date.map { formatter.string(from: $0) } ?? "")"
            }
    }

    @discardableResult
    static func export(metrics: SystemMetrics?, state: AppState?) -> URL? {
        let body = text(metrics: metrics, state: state)
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        let name = "Otter-diagnostics-\(f.string(from: Date())).txt"
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        var target = (desktop ?? FileManager.default.temporaryDirectory).appendingPathComponent(name)
        if !FileManager.default.createFile(atPath: target.path, contents: Data(body.utf8)) {
            target = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try? Data(body.utf8).write(to: target)
        }
        OtterLog.shared.add("导出诊断报告：\(target.path)")
        return target
    }
}
