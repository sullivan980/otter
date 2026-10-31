import Foundation

/// 真实系统采样器（占位：dev-data 负责实现 CPU/内存/磁盘/网络/进程）。
final class RealMetricsSampler: MetricsSampling {
    private let stub = StubSampler()

    func sample() -> SystemMetrics {
        // TODO(dev-data): 用 host_processor_info / host_statistics64 / statfs / getifaddrs / libproc 实现。
        return stub.sample()
    }
}
