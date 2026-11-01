import Foundation
import Darwin

/// 真实系统指标采样器。
///
/// 采样内容：
/// - CPU：`host_processor_info(PROCESSOR_CPU_LOAD_INFO)` 逐核 tick 差分，汇总为用户+系统+nice 占比（0-100，已按全部核心归一）。
/// - 内存：`host_statistics64(HOST_VM_INFO64)` + `hw.memsize`（经 ProcessInfo.physicalMemory），
///   used ≈ App 内存（internal - purgeable）+ wired + compressed，贴近活动监视器口径。
/// - 磁盘：`statfs("/")`。
/// - 网络：`getifaddrs` 读取各网卡 `if_data`（排除 lo0），逐网卡差分后求和，单位 B/s。
/// - TOP3 进程：libproc `proc_listallpids` + `proc_pid_rusage`，CPU 时间差分换算百分比、`ri_phys_footprint` 取内存。
/// - 核数 / 开机时长。
///
/// 线程安全：所有可变差分状态都由同一把锁保护，`sample()` 可被任意队列调用（AppState 每 2s 调用一次）。
/// 采样过程不持有任何长生命周期资源：host_processor_info 的缓冲区用 vm_deallocate 释放，
/// getifaddrs 用 freeifaddrs 释放，进程快照每轮重建，避免内存增长。
final class RealMetricsSampler: MetricsSampling {

    // MARK: - 差分状态

    private let lock = NSLock()

    /// 上一次各核 tick（每核 [user, system, idle, nice]）。
    private var prevCoreTicks: [[UInt64]]?

    /// 上一次各网卡收发字节数。按网卡名保存，网卡增减/计数重置时不会污染合计。
    private var prevNet: [String: (rx: UInt64, tx: UInt64)] = [:]
    /// 上一次网络采样时间（单调时钟，纳秒）。
    private var prevNetTime: UInt64 = 0

    /// 上一次进程 CPU 时间（纳秒）与内存 footprint。
    private var prevProcCPU: [Int32: UInt64] = [:]
    /// 上一次进程采样时间（单调时钟，纳秒）。
    private var prevProcTime: UInt64 = 0

    // MARK: - 常量

    private let coreCount: Int
    private let memTotal: UInt64
    private let pageSize: UInt64
    /// mach 绝对时间与纳秒的换算系数（Apple Silicon 上通常是 125/3，不能假设 1:1）。
    private let timebaseNumer: UInt64
    private let timebaseDenom: UInt64

    /// 单进程名称缓冲区长度（procrustes 默认 MAXCOMLEN=16，这里留足并截断显示）。
    private static let procNameLength: Int = 128
    /// uid 进程总数上限保护，避免异常环境无限扩容。
    private static let maxPIDCount: Int = 8192

    init() {
        coreCount = ProcessInfo.processInfo.activeProcessorCount
        memTotal = ProcessInfo.processInfo.physicalMemory
        var size: vm_size_t = 0
        if host_page_size(mach_host_self(), &size) == KERN_SUCCESS, size > 0 {
            pageSize = UInt64(size)
        } else {
            pageSize = 4096
        }
        var timebase = mach_timebase_info_data_t()
        if mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.numer > 0, timebase.denom > 0 {
            timebaseNumer = UInt64(timebase.numer)
            timebaseDenom = UInt64(timebase.denom)
        } else {
            timebaseNumer = 1
            timebaseDenom = 1
        }
    }

    /// mach absolute time 单位 → 纳秒。
    /// 注意：proc_pid_rusage 的 ri_user_time/ri_system_time 是 mach 绝对时间单位（不是纳秒），
    /// 必须按 timebase 换算，否则 CPU 百分比会低估约 40 倍。
    private func machToNanos(_ units: UInt64) -> UInt64 {
        if timebaseNumer == timebaseDenom { return units }
        let (product, overflow) = units.multipliedReportingOverflow(by: timebaseNumer)
        if overflow {
            // 极端大值（理论上数百年 CPU 时间）才可能溢出，退化为先除后乘。
            return (units / timebaseDenom) * timebaseNumer
        }
        return product / timebaseDenom
    }

    // MARK: - MetricsSampling

    func sample() -> SystemMetrics {
        lock.lock()
        defer { lock.unlock() }

        var m = SystemMetrics()
        m.timestamp = Date()
        m.coreCount = coreCount
        m.uptime = ProcessInfo.processInfo.systemUptime

        let cpu = sampleCPU()
        m.cpuPercent = cpu.total
        m.cpuCores = cpu.cores

        let mem = sampleMemory()
        m.memUsedBytes = mem.used
        m.memTotalBytes = mem.total
        m.memUsedPercent = mem.total > 0 ? min(100, max(0, Double(mem.used) / Double(mem.total) * 100)) : 0

        let disk = sampleDisk()
        m.diskTotalBytes = disk.total
        m.diskUsedBytes = disk.used
        m.diskUsedPercent = disk.total > 0 ? min(100, max(0, Double(disk.used) / Double(disk.total) * 100)) : 0

        let net = sampleNetwork()
        m.downBytesPerSec = net.rxPerSec
        m.upBytesPerSec = net.txPerSec

        m.topProcesses = sampleProcesses()

        m.isReady = true
        return m
    }

    // MARK: - CPU

    /// 返回总负载与每核负载；首次采样按「开机以来」计算。
    private func sampleCPU() -> (total: Double, cores: [Double]) {
        var cpuInfo: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        var cpuCount: natural_t = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfo, &infoCount)
        guard kr == KERN_SUCCESS, let info = cpuInfo, cpuCount > 0 else { return (0, []) }

        defer {
            let bytes = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), bytes)
        }

        var perCore: [[UInt64]] = []
        perCore.reserveCapacity(Int(cpuCount))
        info.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(cpuCount)) { loads in
            for i in 0..<Int(cpuCount) {
                let ticks = loads[i].cpu_ticks
                perCore.append([UInt64(ticks.0), UInt64(ticks.1), UInt64(ticks.2), UInt64(ticks.3)])
            }
        }

        let prev = prevCoreTicks
        prevCoreTicks = perCore

        var cores: [Double] = []
        var busyAll: UInt64 = 0
        var totalAll: UInt64 = 0
        for i in 0..<perCore.count {
            let now = perCore[i]
            let before: [UInt64] = (prev != nil && prev!.count == perCore.count) ? prev![i] : [0, 0, 0, 0]
            var delta = [UInt64](repeating: 0, count: 4)
            for k in 0..<4 { delta[k] = now[k] >= before[k] ? now[k] - before[k] : 0 }
            let busy = delta[0] + delta[1] + delta[3]
            let total = busy + delta[2]
            cores.append(total > 0 ? min(100, max(0, Double(busy) / Double(total) * 100)) : 0)
            busyAll += busy
            totalAll += total
        }
        let total = totalAll > 0 ? min(100, max(0, Double(busyAll) / Double(totalAll) * 100)) : 0
        return (total, cores)
    }

    // MARK: - 内存

    private func sampleMemory() -> (used: UInt64, total: UInt64) {
        let total = memTotal > 0 ? memTotal : ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return (0, total) }

        // App 内存 = internal 页 - 可清除页（purgeable）；wired/compressed 单独相加。
        let internalPages = Int64(stats.internal_page_count)
        let purgeablePages = Int64(stats.purgeable_count)
        let appPages = max(0, internalPages - purgeablePages)
        let usedPages = UInt64(appPages) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        var used = usedPages * pageSize
        if used > total { used = total }
        return (used, total)
    }

    // MARK: - 磁盘

    private func sampleDisk() -> (used: Int64, total: Int64) {
        var fs = statfs()
        guard statfs("/", &fs) == 0 else { return (0, 0) }
        let blockSize = Int64(fs.f_bsize)
        let total = Int64(fs.f_blocks) * blockSize
        let free = Int64(fs.f_bfree) * blockSize
        let used = max(0, total - free)
        return (used, total)
    }

    // MARK: - 网络

    private func sampleNetwork() -> (rxPerSec: Double, txPerSec: Double) {
        var current: [String: (rx: UInt64, tx: UInt64)] = [:]

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return (0, 0) }
        defer { freeifaddrs(first) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            let ifa = ptr.pointee
            cursor = ifa.ifa_next

            guard let addr = ifa.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK),
                  let dataPtr = ifa.ifa_data else { continue }

            let flags = Int32(ifa.ifa_flags)
            guard (flags & IFF_LOOPBACK) == 0 else { continue }

            let name = String(cString: ifa.ifa_name)
            // 只统计有真实收发计数的接口。
            let data = dataPtr.assumingMemoryBound(to: if_data.self).pointee
            current[name] = (rx: UInt64(data.ifi_ibytes), tx: UInt64(data.ifi_obytes))
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = prevNetTime > 0 && now > prevNetTime ? Double(now - prevNetTime) / 1_000_000_000.0 : 0

        var rxDelta: UInt64 = 0
        var txDelta: UInt64 = 0
        if elapsed > 0 {
            for (name, cur) in current {
                guard let old = prevNet[name] else { continue }
                // if_data 的 ifi_ibytes/ifi_obytes 是 32 位计数器：回绕或接口重置时丢弃本轮数据，避免数值爆冲。
                if cur.rx >= old.rx { rxDelta += cur.rx - old.rx }
                if cur.tx >= old.tx { txDelta += cur.tx - old.tx }
            }
        }

        prevNet = current
        prevNetTime = now

        guard elapsed > 0 else { return (0, 0) }
        return (Double(rxDelta) / elapsed, Double(txDelta) / elapsed)
    }

    // MARK: - TOP 进程

    private func sampleProcesses() -> [TopProcess] {
        // 先取数量，再按实际数量分配，避免固定上限截断。
        let rawCount = proc_listallpids(nil, 0)
        guard rawCount > 0 else { return [] }
        let capacity = min(Int(rawCount) + 64, Self.maxPIDCount)
        var pids = [pid_t](repeating: 0, count: capacity)
        let n = proc_listallpids(&pids, Int32(capacity * MemoryLayout<pid_t>.stride))
        guard n > 0 else { return [] }

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = prevProcTime > 0 && now > prevProcTime ? Double(now - prevProcTime) / 1_000_000_000.0 : 0
        var nextCPU: [Int32: UInt64] = [:]
        nextCPU.reserveCapacity(Int(n))
        var rows: [TopProcess] = []
        rows.reserveCapacity(Int(n))

        for i in 0..<Int(n) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var usage = rusage_info_v2()
            let kr = withUnsafeMutablePointer(to: &usage) { ptr -> Int32 in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { infoPtr in
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, infoPtr)
                }
            }
            // 其他用户/系统进程可能返回 EPERM，读不到就跳过（不伪造 0）。
            guard kr == 0 else { continue }

            let cpuNs = machToNanos(usage.ri_user_time + usage.ri_system_time)
            nextCPU[pid] = cpuNs

            var cpuPercent: Double = 0
            if elapsed > 0, let old = prevProcCPU[pid], cpuNs >= old {
                // 单核归一（与活动监视器/ps 的 %CPU 口径一致，多线程进程可超过 100）。
                cpuPercent = Double(cpuNs - old) / (elapsed * 1_000_000_000.0) * 100
            }

            let name = processName(pid: pid)
            rows.append(TopProcess(id: pid,
                                   name: name,
                                   cpuPercent: max(0, cpuPercent),
                                   memBytes: usage.ri_phys_footprint))
        }

        prevProcCPU = nextCPU
        prevProcTime = now

        // 首轮没有 CPU 基线：按内存排序，避免 TOP3 全是 0 造成误解。
        if elapsed <= 0 {
            rows.sort { $0.memBytes > $1.memBytes }
        } else {
            rows.sort { lhs, rhs in
                if lhs.cpuPercent == rhs.cpuPercent { return lhs.memBytes > rhs.memBytes }
                return lhs.cpuPercent > rhs.cpuPercent
            }
        }
        return Array(rows.prefix(3))
    }

    private func processName(pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: Self.procNameLength)
        let ok = buffer.withUnsafeMutableBufferPointer { ptr -> Bool in
            guard let base = ptr.baseAddress else { return false }
            return proc_name(pid, base, UInt32(ptr.count)) > 0
        }
        if ok {
            let name = String(cString: buffer)
            if !name.isEmpty { return name }
        }
        // 回退：用可执行文件路径的 basename（受权限限制可能拿不到）。
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let pathOK = pathBuffer.withUnsafeMutableBufferPointer { ptr -> Bool in
            guard let base = ptr.baseAddress else { return false }
            return proc_pidpath(pid, base, UInt32(ptr.count)) > 0
        }
        if pathOK {
            let path = String(cString: pathBuffer)
            let base = (path as NSString).lastPathComponent
            if !base.isEmpty { return base }
        }
        return "pid \(pid)"
    }
}