import AppKit
import Foundation
import UserNotifications

/// 系统通知：清理 / 卸载的结果走横幅（不再用模态弹窗）。
/// 点按通知：带 section 的跳对应分区，否则打开主界面。
final class Notifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifications()

    /// 点按通知后的跳转回调（StatusBarController 启动时注入）
    var onOpenSection: ((String?) -> Void)?

    private(set) var authorized = false
    private(set) var lastErrorMessage: String?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - 权限

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] ok, err in
            self?.authorized = ok
            if !ok, let err = err {
                self?.lastErrorMessage = "通知授权失败：\(err.localizedDescription)"
                NSLog("[otter] 通知授权失败: %@", err.localizedDescription)
            }
            if let completion = completion {
                DispatchQueue.main.async { completion(ok) }
            }
        }
    }

    /// 供首启引导读取当前授权状态
    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// 打开系统设置的「通知」面板（被拒绝后系统不再弹授权框，只能引导用户手动开启）
    func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.settings.Notifications",
            "x-apple.systempreferences:com.apple.preference.notifications",
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    /// 验收自测：输出授权状态与请求结果（OTTER_SELFTEST=notify）
    func diagnose(completion: @escaping (String) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { before in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, err in
                UNUserNotificationCenter.current().getNotificationSettings { after in
                    let errText = (err?.localizedDescription ?? "").replacingOccurrences(of: "\"", with: "'")
                    let status = after.authorizationStatus
                    let native = (status == .authorized || status == .provisional)
                    self.post(title: "Otter 通知自检",
                              body: native ? "原生通知通道可用。" : "原生通知被系统拒绝，已用脚本通道投递。",
                              section: nil)
                    let json = "{\"mode\":\"notify\",\"before\":\(before.authorizationStatus.rawValue),\"after\":\(status.rawValue),\"granted\":\(ok),\"native\":\(native),\"error\":\"\(errText)\"}"
                    DispatchQueue.main.async { completion(json) }
                }
            }
        }
    }

    // MARK: - 发送

    /// 基础发送（保持原接口不变）
    func post(title: String, body: String) {
        post(title: title, body: body, section: nil)
    }

    /// 发送通知。
    /// macOS 27 实测：ad-hoc 签名（无 Developer ID）的 App 无法获得 UNUserNotificationCenter 授权
    /// （requestAuthorization 直接返回 "Notifications are not allowed for this application"），
    /// 此时自动降级为 AppleScript 的 display notification（由系统自带 osascript 投递，仍会出现横幅）。
    func post(title: String, body: String, section: String?) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self?.postNative(title: title, body: body, section: section)
            default:
                self?.postViaAppleScript(title: title, body: body)
            }
        }
    }

    private func postNative(title: String, body: String, section: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let section = section {
            content.userInfo = ["section": section]
        }
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { [weak self] error in
            guard let error = error else { return }
            self?.lastErrorMessage = "通知发送失败：\(error.localizedDescription)"
            NSLog("[otter] 通知发送失败: %@", error.localizedDescription)
        }
    }

    private func postViaAppleScript(title: String, body: String) {
        func q(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "\"", with: "\\\"")
        }
        let script = "display notification \"\(q(body))\" with title \"\(q(title))\""
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        do {
            try p.run()
            p.waitUntilExit()
            if p.terminationStatus != 0 {
                lastErrorMessage = "通知发送失败（osascript 退出码 \(p.terminationStatus)）"
            }
        } catch {
            lastErrorMessage = "通知发送失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 便捷文案（清理 / 卸载）

    func postCleanFinished(freedBytes: Int64) {
        post(title: "清理完成",
             body: "已释放 \(Fmt.bytes(Double(max(0, freedBytes)))) 空间",
             section: "clean")
    }

    func postCleanFailed(_ reason: String) {
        post(title: "清理没有完成",
             body: reason.isEmpty ? "请稍后重试，或在主界面查看日志。" : reason,
             section: "clean")
    }

    func postUninstallFinished(app: String, bytes: Int64) {
        post(title: "卸载完成",
             body: "\(app) 及其残留已移入废纸篓，共 \(Fmt.bytes(Double(max(0, bytes))))",
             section: "uninstall")
    }

    func postUninstallFailed(app: String, reason: String) {
        post(title: "卸载没有完成",
             body: reason.isEmpty ? "\(app) 未能移入废纸篓，请重试。" : reason,
             section: "uninstall")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 菜单栏 App 常驻前台，也要显示横幅
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let section = response.notification.request.content.userInfo["section"] as? String
        DispatchQueue.main.async { [weak self] in
            self?.onOpenSection?(section)
        }
        completionHandler()
    }
}
