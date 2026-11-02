import Foundation
import Combine

/// 全局状态：指标 + 窗口联动。所有写操作都在主线程。
final class AppState: ObservableObject {
    @Published var metrics = SystemMetrics.zero
    @Published var hudVisible = false { didSet { if oldValue != hudVisible { schedule() } } }
    @Published var selectedSection: String = "clean"
    @Published var isPaused = false

    /// 由 AppDelegate 在启动后注入真实采样器。
    var sampler: MetricsSampling = StubSampler()
    var openMainWindow: (() -> Void)?
    var openMainSection: ((String) -> Void)?

    private var timer: Timer?

    func start() {
        tick()
        isPaused = false
        schedule()
    }

    /// 采样节奏：HUD 可见 1s（看得见的实时），隐藏 2s（省电）。暂停时不排期。
    private func schedule() {
        guard !isPaused else { return }
        timer?.invalidate()
        let interval: TimeInterval = hudVisible ? 1.0 : 2.0
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// 暂停/恢复采集（菜单栏「暂停采集」用）：暂停时停 timer，恢复立即采样一次。
    func setPaused(_ paused: Bool) {
        if paused {
            timer?.invalidate()
            timer = nil
            isPaused = true
        } else {
            start()
        }
    }

    private func checkAlerts(_ m: SystemMetrics) {
        guard Prefs.shared.alertsEnabled else { return }
        for event in AlertMonitor.shared.evaluate(m) {
            Notifications.shared.post(title: event.title, body: event.body)
            OtterLog.shared.add("告警：\(event.title) \(event.body)")
        }
    }

    func tick() {
        let s = sampler
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let m = s.sample()
            DispatchQueue.main.async {
                self?.metrics = m
                self?.checkAlerts(m)
                ReminderService.check(metrics: m)
            }
        }
    }
}