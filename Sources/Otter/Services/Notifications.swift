import Foundation
import UserNotifications

final class Notifications {
    static let shared = Notifications()
    private var authorized = false

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] ok, err in
            self?.authorized = ok
            if !ok, let err = err { NSLog("[otter] 通知授权失败: \(err.localizedDescription)") }
        }
    }

    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
