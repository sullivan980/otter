import Foundation
import Combine

/// 全局状态：指标 + 窗口联动。所有写操作都在主线程。
final class AppState: ObservableObject {
    @Published var metrics = SystemMetrics.zero
    @Published var hudVisible = false
    @Published var selectedSection: String = "clean"

    /// 由 AppDelegate 在启动后注入真实采样器。
    var sampler: MetricsSampling = StubSampler()
    var openMainWindow: (() -> Void)?
    var openMainSection: ((String) -> Void)?

    private var timer: Timer?

    func start() {
        tick()
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func tick() {
        let s = sampler
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let m = s.sample()
            DispatchQueue.main.async { self?.metrics = m }
        }
    }
}
