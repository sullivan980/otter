import Foundation
import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    static func setEnabled(_ on: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if on {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("[otter] 登录项设置失败: \(error.localizedDescription)")
        }
    }
}
