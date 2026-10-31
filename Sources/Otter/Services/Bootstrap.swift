import Foundation

// 数据层实现的注入点（dev-data 负责：把真实服务装进 Services.shared）。
// 目前为空，UI 在服务未就绪时显示「服务未就绪」。
func bootstrapServices() {
    // TODO(dev-data): Services.shared.clean = CleanService()
    //                Services.shared.uninstall = UninstallService()
}
/// 验收自测（dev-data 负责扩充 clean/uninstall；当前先保证可编译并输出指标）
func runSelfTest(mode: String) {
    let m = RealMetricsSampler().sample()
    switch mode {
    case "clean":
        print("{\"mode\":\"clean\",\"note\":\"not implemented yet\"}")
    case "uninstall":
        print("{\"mode\":\"uninstall\",\"note\":\"not implemented yet\"}")
    default:
        let json = String(
            format: "{\"mode\":\"metrics\",\"cpu\":%.1f,\"mem_used_pct\":%.1f,\"mem_total\":%llu,\"disk_total\":%lld,\"down\":%.0f,\"up\":%.0f,\"cores\":%d,\"top\":%d}",
            m.cpuPercent, m.memUsedPercent, m.memTotalBytes, m.diskTotalBytes,
            m.downBytesPerSec, m.upBytesPerSec, m.coreCount, m.topProcesses.count)
        print(json)
    }
}
