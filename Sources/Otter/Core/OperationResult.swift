import SwiftUI
import Combine

struct OperationResult: Identifiable, Equatable {
    enum Kind { case success, warning, error }
    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
    let timestamp = Date()
}

/// 应用内结果卡片中心：清理 / 卸载 / 空间 / 维护完成后弹一张卡，避免只依赖系统通知。
final class OperationResultCenter: ObservableObject {
    static let shared = OperationResultCenter()
    @Published private(set) var current: OperationResult?
    private var dismissWork: DispatchWorkItem?

    private init() {}

    func post(kind: OperationResult.Kind, title: String, message: String, autoDismiss: TimeInterval = 8) {
        dismissWork?.cancel()
        current = OperationResult(kind: kind, title: title, message: message)
        guard autoDismiss > 0 else { return }
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismiss, execute: work)
    }

    func dismiss() {
        dismissWork?.cancel()
        dismissWork = nil
        current = nil
    }
}
