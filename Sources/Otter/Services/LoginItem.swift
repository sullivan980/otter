import AppKit
import Foundation
import ServiceManagement

/// 登录自启（macOS 13+ 用 SMAppService.mainApp）。
///
/// 约定：
///   · isEnabled / setEnabled(_:) 供 AppDelegate 与设置页调用；
///   · 失败绝不吞：记录 lastErrorMessage、打日志、发 changedNotification，
///     informUser: true 时弹系统提示（引导/设置手动操作时用）；
///   · requiresApproval（首次注册常需用户在系统设置里允许）单独给出文案与跳转。
enum LoginItem {
    enum Status: String {
        case enabled
        case notRegistered
        case requiresApproval
        case notFound
        case unsupported
        case failed
    }

    static let changedNotification = Notification.Name("OtterLoginItemChanged")

    private(set) static var lastErrorMessage: String?

    static var isAvailable: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    static var status: Status {
        guard #available(macOS 13.0, *) else { return .unsupported }
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .notRegistered: return .notRegistered
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .failed
        }
    }

    static var isEnabled: Bool { status == .enabled }

    /// 供设置页 / 引导展示
    static var statusText: String {
        switch status {
        case .enabled: return "已开启"
        case .notRegistered: return "未开启"
        case .requiresApproval: return "等待系统确认"
        case .notFound: return "系统未找到应用"
        case .unsupported: return "macOS 13 以下不支持"
        case .failed: return "状态未知"
        }
    }

    /// 详细说明（失败原因 / 需要用户操作的原因）
    static var detailText: String? {
        if let error = lastErrorMessage { return error }
        if status == .requiresApproval {
            return "需要到「系统设置 › 通用 › 登录项」中允许 Otter"
        }
        return nil
    }

    /// 设置开机自启。返回「最终是否处于开启状态」；失败返回 false 并记录原因。
    @discardableResult
    static func setEnabled(_ on: Bool, informUser: Bool = false) -> Bool {
        guard #available(macOS 13.0, *) else {
            report("当前系统低于 macOS 13，暂不支持登录自启", informUser: informUser)
            return false
        }

        let service = SMAppService.mainApp
        do {
            if on {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status != .notRegistered { try service.unregister() }
            }
        } catch {
            report("登录自启设置失败：\(error.localizedDescription)", informUser: informUser)
            return false
        }

        if on, service.status == .requiresApproval {
            lastErrorMessage = "需要在「系统设置 › 通用 › 登录项」中允许 Otter，自启才会真正生效"
        } else {
            lastErrorMessage = nil
        }
        postChanged()
        return service.status == .enabled
    }

    /// 打开系统设置的「登录项」面板
    static func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.users?LoginItems",
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    /// 手动操作失败时把错误显示出来
    static func presentFailureAlertIfNeeded() {
        guard let message = lastErrorMessage else { return }
        let alert = NSAlert()
        alert.messageText = "登录自启没有设置成功"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "知道了")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openSystemSettings()
        }
    }

    private static func report(_ message: String, informUser: Bool) {
        lastErrorMessage = message
        NSLog("[otter] %@", message)
        postChanged()
        if informUser { presentFailureAlertIfNeeded() }
    }

    private static func postChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: LoginItem.changedNotification, object: nil)
        }
    }
}
