import AppKit

/// 首启引导（dev-shell 实现三步窗口）。当前为占位：仅记录已引导标记。
final class OnboardingController {
    static let shared = OnboardingController()
    private init() {}

    func presentIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "otterOnboarded") else { return }
        // TODO(dev-shell): 三步引导（介绍 → 权限 → 自启+菜单栏预设）
    }
}
