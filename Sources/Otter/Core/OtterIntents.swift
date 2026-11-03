import Foundation
import AppKit
import AppIntents

@available(macOS 13.0, *)
enum OtterSection: String, AppEnum {
    case clean, uninstall, startup, maintenance, disk, settings

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Otter 分区"
    static var caseDisplayRepresentations: [OtterSection: DisplayRepresentation] = [
        .clean: "清理",
        .uninstall: "卸载",
        .startup: "启动项",
        .maintenance: "维护",
        .disk: "磁盘",
        .settings: "设置",
    ]
}

@available(macOS 13.0, *)
struct OtterSystemSnapshotIntent: AppIntent {
    static var title: LocalizedStringResource = "读取 Otter 系统快照"
    static var description = IntentDescription("返回当前 CPU / 内存 / 磁盘 / 上传 / 下载。")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let sampler = RealMetricsSampler()
        _ = sampler.sample()
        try? await Task.sleep(nanoseconds: 600_000_000)
        let m = sampler.sample()
        let text = "CPU \(Fmt.percent(m.cpuPercent)) · 内存 \(Fmt.percent(m.memUsedPercent)) · 磁盘 \(Fmt.percent(m.diskUsedPercent)) · ↑\(Fmt.rate(m.upBytesPerSec)) ↓\(Fmt.rate(m.downBytesPerSec))"
        return .result(value: text)
    }
}

@available(macOS 13.0, *)
struct OtterOpenSectionIntent: AppIntent {
    static var title: LocalizedStringResource = "打开 Otter 分区"
    static var description = IntentDescription("打开 Otter 主界面的指定分区。")

    @Parameter(title: "分区")
    var section: OtterSection

    func perform() async throws -> some IntentResult {
        if let url = URL(string: "otter://\(section.rawValue)") {
            NSWorkspace.shared.open(url)
        }
        return .result()
    }
}

@available(macOS 13.0, *)
struct OtterShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OtterSystemSnapshotIntent(),
                    phrases: ["读取 Otter 系统快照", "Get Otter system snapshot"])
        AppShortcut(intent: OtterOpenSectionIntent(),
                    phrases: ["打开 Otter 分区", "Open Otter section"])
    }
}