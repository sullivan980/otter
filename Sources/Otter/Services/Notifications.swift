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

    // MARK: - 发送

    /// 基础发送（保持原接口不变）
    func post(title: String, body: String) {
        post(title: title, body: body, section: nil)
    }

    func post(title: String, body: String, section: String?) {
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
