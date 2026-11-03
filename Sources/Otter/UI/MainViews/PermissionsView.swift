import SwiftUI
import AppKit
import Foundation

// MARK: - 系统权限检测（全磁盘 / 自动化）
//
// 全磁盘：探测受 TCC 保护的文件是否可读（无授权时 fileExists 可见但读取失败）。
// 自动化：osascript 控制 System Events，4 秒超时（弹授权框时按失败处理，不阻塞界面）。
final class PermissionModel: ObservableObject {
    enum Status: Equatable {
        case unknown
        case checking
        case granted
        case denied
        case timeout
        case failed(String)

        var isGranted: Bool { self == .granted }
        var isChecking: Bool { self == .checking }
    }

    @Published private(set) var fullDisk: Status = .unknown
    @Published private(set) var automation: Status = .unknown
    @Published private(set) var checkedAt: Date?

    private let lock = NSLock()
    private var generationValue = 0
    private var didAutoCheck = false

    /// 4 秒超时（需求硬指标）。
    static let timeout: TimeInterval = 4

    func autoCheckIfNeeded() {
        guard !didAutoCheck else { return }
        didAutoCheck = true
        // 自动只查全磁盘（静默、无弹窗）；自动化会触发系统授权弹窗，交给用户手动点。
        checkFullDisk()
    }

    func checkAll() {
        checkFullDisk()
        checkAutomation()
    }

    private func nextGeneration() -> Int {
        lock.lock(); defer { lock.unlock() }
        generationValue += 1
        return generationValue
    }

    private func isCurrent(_ generation: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return generationValue == generation
    }

    // MARK: 全磁盘访问

    func checkFullDisk() {
        fullDisk = .checking
        let generation = nextGeneration()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let status = Self.probeFullDisk()
            DispatchQueue.main.async {
                guard let self = self, self.isCurrent(generation) else { return }
                self.fullDisk = status
                self.checkedAt = Date()
            }
        }
    }

    private static func probeFullDisk() -> Status {
        let home = NSHomeDirectory()
        let candidates: [(path: String, isDirectory: Bool)] = [
            (home + "/Library/Application Support/com.apple.TCC/TCC.db", false),
            ("/Library/Application Support/com.apple.TCC/TCC.db", false),
            (home + "/Library/Safari", true),
            (home + "/Library/Mail", true)
        ]
        var sawExisting = false
        for candidate in candidates {
            guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
            sawExisting = true
            if candidate.isDirectory {
                if (try? FileManager.default.contentsOfDirectory(atPath: candidate.path)) != nil {
                    return .granted
                }
            } else {
                if let handle = FileHandle(forReadingAtPath: candidate.path) {
                    handle.closeFile()
                    return .granted
                }
            }
        }
        return sawExisting ? .denied : .unknown
    }

    // MARK: 自动化（控制 System Events）

    func checkAutomation() {
        automation = .checking
        let generation = nextGeneration()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "tell application \"System Events\" to get name of first application process"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let timedOutFlag = NSLockedFlag()

        do {
            try process.run()
        } catch {
            automation = .failed(L("无法运行 osascript：\(error.localizedDescription)","Cannot run osascript: \(error.localizedDescription)"))
            return
        }

        // 4 秒超时：终止子进程并标记超时（避免无限等待系统授权框）。
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + Self.timeout) { [weak process] in
            guard let process = process, process.isRunning else { return }
            timedOutFlag.set()
            process.terminate()
        }

        process.terminationHandler = { [weak self] proc in
            let output = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
            let text = String(data: output, encoding: .utf8) ?? ""
            let timedOut = timedOutFlag.value
            let status: Status
            if timedOut {
                status = .timeout
            } else if proc.terminationStatus == 0 {
                status = .granted
            } else if text.contains("-1743") || text.contains("not allowed") || text.contains(L("不允许","Not allowed")) {
                status = .denied
            } else {
                status = .failed(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                 ? L("退出码 \(proc.terminationStatus)","Exit code \(proc.terminationStatus)")
                                 : L("退出码 \(proc.terminationStatus)：\(text.prefix(120))","Exit code \(proc.terminationStatus): \(text.prefix(120))"))
            }
            DispatchQueue.main.async {
                guard let self = self, self.isCurrent(generation) else { return }
                self.automation = status
                self.checkedAt = Date()
            }
        }
    }

    // MARK: 跳转系统设置

    static func openFullDiskSettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    static func openAutomationSettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    private static func openSettings(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// 轻量线程安全布尔（终止超时标记）。
private final class NSLockedFlag {
    private let lock = NSLock()
    private var flag = false
    func set() { lock.lock(); flag = true; lock.unlock() }
    var value: Bool { lock.lock(); defer { lock.unlock() }; return flag }
}

// MARK: - 权限设置分区
struct PermissionSection: View {
    @ObservedObject var model: PermissionModel

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SubHeader(text: L("系统权限","Permissions"))
                    Spacer()
                    if model.fullDisk.isChecking || model.automation.isChecking {
                        ProgressView().controlSize(.small)
                    }
                    Button(L("重新检测全部","Recheck All")) { model.checkAll() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Text(L("Otter 需要下列权限才能发挥完整能力。未开启时点右侧按钮跳到系统设置，开启后回到这里重新检测。自动化检测会弹出系统授权框，超时 \(Int(PermissionModel.timeout)) 秒按未开启处理。","Otter needs these permissions for full functionality. Open System Settings with the button, then recheck here. Automation prompts for authorization; timeout is \(Int(PermissionModel.timeout))s."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                permissionRow(title: L("全磁盘访问","Full Disk Access"),
                              why: L("统计废纸篓大小、读取受保护目录，清理与磁盘分析更准确","More accurate Trash size, protected folders, cleaning and disk analysis"),
                              status: model.fullDisk,
                              checkTitle: L("检测","Check"),
                              check: { model.checkFullDisk() },
                              openSettings: { PermissionModel.openFullDiskSettings() })

                Divider()

                permissionRow(title: L("自动化（控制 System Events）","Automation (System Events)"),
                              why: L("执行需要系统事件代办的卸载/清理动作；首次检测会请求授权","Required for automation-based actions; first check asks for authorization"),
                              status: model.automation,
                              checkTitle: L("检测自动化","Check Automation"),
                              check: { model.checkAutomation() },
                              openSettings: { PermissionModel.openAutomationSettings() })
            }
        }
    }

    private func permissionRow(title: String,
                               why: String,
                               status: PermissionModel.Status,
                               checkTitle: String,
                               check: @escaping () -> Void,
                               openSettings: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 10) {
            statusView(status)
                .frame(width: 74, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(why).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(checkTitle, action: check)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(status.isChecking)
            if !status.isGranted {
                Button(L("打开设置","Open Settings")) { openSettings() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func statusView(_ status: PermissionModel.Status) -> some View {
        switch status {
        case .granted:
            Label(L("已开启","Enabled"), systemImage: "checkmark.circle.fill")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.green)
        case .denied:
            Label(L("未开启","Disabled"), systemImage: "xmark.circle.fill")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.orange)
        case .checking:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text(L("检测中","Checking")).font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
        case .timeout:
            Label(L("超时","Timeout"), systemImage: "clock.badge.exclamationmark")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.orange)
        case .unknown:
            Label(L("未知","Unknown"), systemImage: "questionmark.circle")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        case .failed(let message):
            Label(L("检测失败","Check failed"), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.red)
                .help(message)
        }
    }
}
