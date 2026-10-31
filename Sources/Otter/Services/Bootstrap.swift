import Foundation

// 数据层实现的注入点（dev-data 负责：把真实服务装进 Services.shared）。
// UI 在服务未就绪时显示「服务未就绪」。
func bootstrapServices() {
    Services.shared.clean = CleanService()
    Services.shared.uninstall = UninstallService()
}

/// 验收自测入口（AppDelegate 在 OTTER_SELFTEST 存在时调用，完成后自行 exit）。
///
/// 支持的模式（全部只读，红线：不执行真实清理/优化/删除）：
/// - metrics：真实采样两次（间隔 1.2s 用于差分），打印一行 JSON 指标；
/// - clean：真实跑一次 `mole clean --dry-run`，打印分类数/条目数/总大小；
/// - uninstall：列出应用并扫描第一个应用的关联残留；
/// - parse：读取 OTTER_SELFTEST_INPUT 指定的 mole dry-run 原始文本，仅解析不执行；
/// - trash-empty：对空数组走 UninstallService.trash 的守护路径，不触碰任何真实文件。
func runSelfTest(mode: String) {
    switch mode {
    case "clean":
        runSelfTestClean()
    case "uninstall":
        runSelfTestUninstall()
    case "parse":
        runSelfTestParse()
    case "trash-empty":
        runSelfTestTrashEmpty()
    default:
        runSelfTestMetrics()
    }
}

// MARK: - metrics

private func runSelfTestMetrics() {
    let sampler = RealMetricsSampler()
    // 第一次采样建立 CPU/网络/进程差分基线；间隔一小段时间后取真实增量。
    _ = sampler.sample()
    Thread.sleep(forTimeInterval: 1.2)
    let m = sampler.sample()

    let top = m.topProcesses.map { process -> [String: Any] in
        [
            "pid": Int(process.id),
            "name": process.name,
            "cpu": roundTo(process.cpuPercent, 1),
            "mem": Int64(process.memBytes)
        ]
    }

    var dict: [String: Any] = [
        "mode": "metrics",
        "ok": m.isReady,
        "cpu": roundTo(m.cpuPercent, 1),
        "mem_used_pct": roundTo(m.memUsedPercent, 1),
        "mem_used": Int64(m.memUsedBytes),
        "mem_total": Int64(m.memTotalBytes),
        "disk_used_pct": roundTo(m.diskUsedPercent, 1),
        "disk_used": m.diskUsedBytes,
        "disk_total": m.diskTotalBytes,
        "down": Int64(m.downBytesPerSec.rounded()),
        "up": Int64(m.upBytesPerSec.rounded()),
        "cores": m.coreCount,
        "uptime": Int64(m.uptime),
        "top": top,
        "machine_mem_total": Int64(ProcessInfo.processInfo.physicalMemory)
    ]
    // 合法性保护：自测输出必须让验收脚本能直接断言。
    if (m.cpuPercent < 0 || m.cpuPercent > 100) { dict["cpu_warning"] = "out_of_range" }
    if m.memTotalBytes == 0 { dict["mem_warning"] = "total_bytes_zero" }
    emitSelfTestJSON(dict)
}

// MARK: - clean（真实 dry-run，只读）

private func runSelfTestClean() {
    let service = CleanService()
    service.callbackQueue = DispatchQueue(label: "com.ottermac.selftest.clean", qos: .userInitiated)

    let semaphore = DispatchSemaphore(value: 0)
    var outcome: Result<CleanPlan, Error>?
    let started = Date()

    service.preview(onLine: { _ in }, completion: { result in
        outcome = result
        semaphore.signal()
    })

    let waitResult = semaphore.wait(timeout: .now() + 960)
    let duration = Int(Date().timeIntervalSince(started) * 1000)

    guard waitResult == .success, let result = outcome else {
        emitSelfTestJSON(["mode": "clean", "ok": false, "error": "dry-run 超时（960s）", "duration_ms": duration])
        return
    }

    switch result {
    case .failure(let error):
        emitSelfTestJSON([
            "mode": "clean",
            "ok": false,
            "error": error.localizedDescription,
            "duration_ms": duration
        ])
    case .success(let plan):
        let itemCount = plan.categories.reduce(0) { $0 + $1.items.count }
        let nonEmpty = plan.categories.filter { $0.bytes > 0 || !$0.items.isEmpty }.count
        let summary = CleanService.parseSummary(plan.rawText)
        var dict: [String: Any] = [
            "mode": "clean",
            "ok": true,
            "categories": plan.categories.count,
            "nonEmptyCategories": nonEmpty,
            "items": itemCount,
            "totalBytes": plan.totalBytes,
            "duration_ms": duration,
            "categories_detail": plan.categories.map { category -> [String: Any] in
                ["title": category.title, "bytes": category.bytes, "items": category.items.count]
            }
        ]
        if let summary = summary {
            dict["summary_categories"] = summary.categories
        }
        // CleanPlan 已内置摘要值（potentialBytes/summaryItems），优先使用。
        dict["summary_items"] = plan.summaryItems ?? summary?.items ?? 0
        dict["potential_bytes"] = plan.potentialBytes ?? summary?.potentialBytes ?? plan.totalBytes
        if let rawPath = ProcessInfo.processInfo.environment["OTTER_SELFTEST_RAW"], !rawPath.isEmpty {
            try? plan.rawText.write(toFile: rawPath, atomically: true, encoding: .utf8)
            dict["raw_dump"] = rawPath
        }
        emitSelfTestJSON(dict)
    }
}

// MARK: - parse（仅解析给定文本，不运行 mole）

private func runSelfTestParse() {
    let env = ProcessInfo.processInfo.environment
    guard let inputPath = env["OTTER_SELFTEST_INPUT"], !inputPath.isEmpty else {
        emitSelfTestJSON(["mode": "parse", "ok": false, "error": "缺少 OTTER_SELFTEST_INPUT"])
        return
    }
    guard let raw = try? String(contentsOfFile: inputPath, encoding: .utf8) else {
        emitSelfTestJSON(["mode": "parse", "ok": false, "error": "无法读取输入文件：\(inputPath)"])
        return
    }

    let plan = CleanService.parsePlan(raw)
    let itemCount = plan.categories.reduce(0) { $0 + $1.items.count }
    let summary = CleanService.parseSummary(raw)
    var dict: [String: Any] = [
        "mode": "parse",
        "ok": true,
        "categories": plan.categories.count,
        "items": itemCount,
        "totalBytes": plan.totalBytes,
        "summary_categories": summary?.categories ?? 0,
        "summary_items": plan.summaryItems ?? summary?.items ?? 0,
        "potential_bytes": plan.potentialBytes ?? summary?.potentialBytes ?? plan.totalBytes
    ]
    dict["nonEmptyCategories"] = plan.categories.filter { $0.bytes > 0 || !$0.items.isEmpty }.count
    emitSelfTestJSON(dict)
}

// MARK: - uninstall（只读扫描）

private func runSelfTestUninstall() {
    let service = UninstallService()
    service.callbackQueue = DispatchQueue(label: "com.ottermac.selftest.uninstall", qos: .userInitiated)

    let semaphore = DispatchSemaphore(value: 0)
    var apps: [AppItem] = []
    var listError: Error?

    service.listApps { result in
        switch result {
        case .success(let value): apps = value
        case .failure(let error): listError = error
        }
        semaphore.signal()
    }

    guard semaphore.wait(timeout: .now() + 60) == .success else {
        emitSelfTestJSON(["mode": "uninstall", "ok": false, "error": "枚举应用超时"])
        return
    }
    if let error = listError {
        emitSelfTestJSON(["mode": "uninstall", "ok": false, "error": error.localizedDescription])
        return
    }
    guard let first = apps.first else {
        emitSelfTestJSON(["mode": "uninstall", "ok": false, "apps": 0, "error": "没有找到应用"])
        return
    }

    service.scan(first) { result in
        switch result {
        case .success(let scan):
            var kinds: [String: Int] = [:]
            for item in scan.leftovers { kinds[item.kind, default: 0] += 1 }
            emitSelfTestJSON([
                "mode": "uninstall",
                "ok": true,
                "apps": apps.count,
                "first_app": [
                    "name": scan.app.name,
                    "bundleId": scan.app.bundleId ?? "",
                    "leftovers": scan.leftovers.count,
                    "totalBytes": scan.totalBytes,
                    "kinds": kinds
                ]
            ])
        case .failure(let error):
            emitSelfTestJSON([
                "mode": "uninstall",
                "ok": false,
                "apps": apps.count,
                "first_app": first.name,
                "error": error.localizedDescription
            ])
        }
        semaphore.signal()
    }

    if semaphore.wait(timeout: .now() + 300) != .success {
        emitSelfTestJSON(["mode": "uninstall", "ok": false, "apps": apps.count, "error": "扫描残留超时"])
    }
}

// MARK: - trash-empty（守护路径，不删除任何文件）

private func runSelfTestTrashEmpty() {
    let service = UninstallService()
    service.callbackQueue = DispatchQueue(label: "com.ottermac.selftest.trash", qos: .userInitiated)

    let semaphore = DispatchSemaphore(value: 0)
    var trashed = 0
    var success = false
    var errorMessage: String?

    service.trash([]) { result in
        switch result {
        case .success(let count):
            trashed = count
            success = true
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
        semaphore.signal()
    }

    guard semaphore.wait(timeout: .now() + 30) == .success else {
        emitSelfTestJSON(["mode": "trash-empty", "ok": false, "error": "trash 调用超时"])
        return
    }

    // 严格按验收约定输出 {"mode":"trash-empty","trashed":0,"success":true}，不额外加字段。
    var dict: [String: Any] = [
        "mode": "trash-empty",
        "trashed": trashed,
        "success": success
    ]
    if let errorMessage = errorMessage {
        dict["error"] = errorMessage
    }
    emitSelfTestJSON(dict)
}

// MARK: - 输出工具

/// 打印一行 JSON（键排序保证可复现），并在 OTTER_SELFTEST_OUT 指定时落盘。
/// 说明：通过 `open` 启动的 app 拿不到终端 stdout，落盘用于自动验收与证据留存。
private func emitSelfTestJSON(_ dictionary: [String: Any]) {
    let json: String
    if let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]),
       let text = String(data: data, encoding: .utf8) {
        json = text
    } else {
        json = "{\"mode\":\"unknown\",\"ok\":false,\"error\":\"JSON 序列化失败\"}"
    }
    print(json)
    fflush(stdout)

    if let outPath = ProcessInfo.processInfo.environment["OTTER_SELFTEST_OUT"], !outPath.isEmpty {
        try? json.write(toFile: outPath, atomically: true, encoding: .utf8)
    }
}

private func roundTo(_ value: Double, _ places: Int) -> Double {
    let scale = pow(10.0, Double(places))
    return (value * scale).rounded() / scale
}
