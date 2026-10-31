import Foundation

/// 清理服务错误。
enum CleanServiceError: LocalizedError {
    case busy
    case moleMissing
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .busy:
            return "已有清理任务在运行，请等待完成或先取消"
        case .moleMissing:
            return "找不到内置 mole，无法执行清理"
        case .cancelled:
            return "已取消清理"
        case .failed(let message):
            return message
        }
    }
}

/// 清理服务：把 mole 的 dry-run 预览文本解析为 CleanPlan，并流式执行真实清理。
///
/// 设计要点：
/// - sudo 完全交给 mole 自己处理（它会弹 osascript 授权对话框），本服务不预取密码、不调用 sudo -v；
/// - preview 只跑 `clean --dry-run`（只读，绝不删除），真实 run 才执行 `clean`；
/// - 预览解析逻辑对齐旧版 WebView 的 parseMolePlan/parseCleanSummary：
///   分类行以 ➤ 开头，条目行以 →（将清理）/ ✓（无可清理）/ ⊙（需复核）/ ◎（需 sudo）等标记开头；
/// - 同一时刻只允许一个任务，避免并发 mole 进程互相干扰；
/// - 回调默认投递到主队列（UI 直接消费），自测可把 callbackQueue 换成后台队列。
final class CleanService: CleanServicing {

    /// 回调投递队列。UI 场景保持默认主队列；自测为避免阻塞主线程可改为后台队列。
    var callbackQueue: DispatchQueue = .main

    private let runner: MoleRunner
    private let lock = NSLock()
    private var currentTask: MoleTask?
    private var busy = false

    /// dry-run 全量扫描可能 1-2 分钟，给足 15 分钟；真实清理给 30 分钟。
    private let previewTimeout: TimeInterval = 900
    private let runTimeout: TimeInterval = 1800

    init(runner: MoleRunner = .shared) {
        self.runner = runner
    }

    // MARK: - CleanServicing

    func preview(onLine: @escaping (String) -> Void, completion: @escaping (Result<CleanPlan, Error>) -> Void) {
        guard beginTask() else {
            deliver { completion(.failure(CleanServiceError.busy)) }
            return
        }

        var collected: [String] = []
        let collectLock = NSLock()

        let task = runner.run(args: ["clean", "--dry-run"], timeout: previewTimeout, onLine: { [weak self] line in
            collectLock.lock()
            collected.append(line)
            collectLock.unlock()
            guard let self = self else { return }
            self.deliver { onLine(line) }
        }, completion: { [weak self] result in
            collectLock.lock()
            let text = collected.joined(separator: "\n")
            collectLock.unlock()

            guard let self = self else { return }
            self.endTask()

            guard result.launched else {
                self.deliver {
                    completion(.failure(CleanServiceError.failed(result.errorMessage ?? "mole 启动失败")))
                }
                return
            }
            if result.cancelled {
                self.deliver { completion(.failure(CleanServiceError.cancelled)) }
                return
            }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let message = result.timedOut ? "mole 扫描超时（\(Int(self.previewTimeout))s）" : "mole 未输出任何内容（退出码 \(result.exitCode)）"
                self.deliver { completion(.failure(CleanServiceError.failed(message))) }
                return
            }

            // mole 在诊断任务超时等场景可能退出码非 0，但预览文本仍然完整；照旧解析，不因退出码丢弃结果。
            let plan = Self.parsePlan(text)
            self.deliver { completion(.success(plan)) }
        })

        if let task = task {
            lock.lock()
            // 极快结束的任务可能在赋值前已经回调 endTask，这里判 busy 避免把陈旧句柄写回。
            if busy { currentTask = task }
            lock.unlock()
        }
    }

    func run(onProgress: @escaping (CleanProgress) -> Void, completion: @escaping (Result<CleanResult, Error>) -> Void) {
        guard beginTask() else {
            deliver { completion(.failure(CleanServiceError.busy)) }
            return
        }

        var collected: [String] = []
        let collectLock = NSLock()

        let task = runner.run(args: ["clean"], timeout: runTimeout, onLine: { [weak self] line in
            collectLock.lock()
            collected.append(line)
            collectLock.unlock()
            guard let self = self else { return }
            self.deliver { onProgress(CleanProgress(phase: "清理中", line: line)) }
        }, completion: { [weak self] result in
            collectLock.lock()
            let text = collected.joined(separator: "\n")
            collectLock.unlock()

            guard let self = self else { return }
            self.endTask()

            guard result.launched else {
                self.deliver {
                    completion(.failure(CleanServiceError.failed(result.errorMessage ?? "mole 启动失败")))
                }
                return
            }
            if result.cancelled {
                self.deliver { completion(.failure(CleanServiceError.cancelled)) }
                return
            }
            let freed = Self.parseFreedBytes(text)
            let success = result.exitCode == 0 && !result.timedOut
            self.deliver {
                completion(.success(CleanResult(success: success, freedBytes: freed, output: text)))
            }
        })

        if let task = task {
            lock.lock()
            if busy { currentTask = task }
            lock.unlock()
        }
    }

    func cancel() {
        lock.lock()
        let task = currentTask
        lock.unlock()
        task?.cancel()
    }

    // MARK: - 任务串行化

    private func beginTask() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if busy { return false }
        busy = true
        currentTask = nil
        return true
    }

    private func endTask() {
        lock.lock(); defer { lock.unlock() }
        busy = false
        currentTask = nil
    }

    private func deliver(_ block: @escaping () -> Void) {
        callbackQueue.async(execute: block)
    }

    // MARK: - 输出解析（对齐旧版 parseMolePlan / parseCleanSummary）

    /// 分类标题标记（mole lib/core/base.sh: ICON_ARROW）。
    private static let categoryMarker: Character = "➤"
    /// 条目标记：→ 将清理、✓ 无可清理、⊙ 需复核、◎ 需 sudo、✗/●/○/• 其他状态。
    private static let itemMarkers = Set<Character>(["→", "✓", "⊙", "◎", "✗", "●", "○", "•"])
    /// 表示「该分类没有可清理项」的文案（大小写不敏感）。
    private static let emptyItemPrefixes = ["nothing to clean", "nothing to tidy"]

    /// 去掉 ANSI 转义序列（mole 在管道下通常不输出颜色，但自测/调试可能带颜色）。
    static func stripANSI(_ text: String) -> String {
        let pattern = "\u{001B}\\[[0-9;?]*[ -/]*[@-~]"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// 解析 mole 预览文本为 CleanPlan。
    /// 保留全部分类（含无可清理分类，bytes=0），方便 UI 折叠展示；原始文本保留在 rawText 里。
    static func parsePlan(_ raw: String) -> CleanPlan {
        let text = stripANSI(raw)
        var titles: [String] = []
        var itemsByCategory: [[CleanItem]] = []
        var bytesByCategory: [Int64] = []
        var current: Int?

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let first = line.first else { continue }

            if first == categoryMarker {
                let title = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { continue }
                titles.append(title)
                itemsByCategory.append([])
                bytesByCategory.append(0)
                current = titles.count - 1
                continue
            }

            guard let index = current, itemMarkers.contains(first) else { continue }
            let rest = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            guard !rest.isEmpty else { continue }
            let lower = rest.lowercased()
            if emptyItemPrefixes.contains(where: { lower.hasPrefix($0) }) { continue }

            let (label, bytes) = splitLabelAndSize(rest)
            guard !label.isEmpty else { continue }
            let item = CleanItem(id: "cat\(index)-item\(itemsByCategory[index].count)-\(label)",
                                 label: label,
                                 bytes: bytes)
            itemsByCategory[index].append(item)
            bytesByCategory[index] += bytes
        }

        let categories = titles.enumerated().map { index, title in
            CleanCategory(id: "cat\(index)-\(title)",
                          title: title,
                          bytes: bytesByCategory[index],
                          items: itemsByCategory[index])
        }
        // mole 摘要（Potential space / Items / Categories）是权威的对外口径：
        // 逐行汇总会因 mole 跨分类重复渲染而偏高，所以单独保存摘要值供 UI 优先展示。
        let summary = parseSummary(raw)
        var plan = CleanPlan(categories: categories, rawText: raw)
        plan.potentialBytes = summary?.potentialBytes
        plan.summaryItems = summary?.items
        return plan
    }

    /// 把「描述 · 1KB dry」「描述 · 2 items, 12MB dry」「描述 · 0B · review with …」拆成描述与字节数。
    private static func splitLabelAndSize(_ line: String) -> (String, Int64) {
        let parts = line.components(separatedBy: " · ").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = parts.first, !first.isEmpty else { return ("", 0) }
        for part in parts.dropFirst() {
            if let bytes = parseHumanBytes(part) { return (first, bytes) }
        }
        return (first, 0)
    }

    /// 解析人类可读大小。mole 的 bytes_to_human 用十进制（1KB = 1000B），与 df 口径一致。
    static func parseHumanBytes(_ token: String) -> Int64? {
        let pattern = "([0-9]+(?:\\.[0-9]+)?)\\s*(B|KB|MB|GB|TB)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(token.startIndex..<token.endIndex, in: token)
        guard let match = regex.firstMatch(in: token, options: [], range: range),
              match.numberOfRanges >= 3,
              let valueRange = Range(match.range(at: 1), in: token),
              let unitRange = Range(match.range(at: 2), in: token),
              let value = Double(token[valueRange]) else { return nil }
        let unit = token[unitRange].uppercased()
        let multiplier: Double
        switch unit {
        case "B": multiplier = 1
        case "KB": multiplier = 1_000
        case "MB": multiplier = 1_000_000
        case "GB": multiplier = 1_000_000_000
        case "TB": multiplier = 1_000_000_000_000
        default: return nil
        }
        let bytes = value * multiplier
        guard bytes >= 0, bytes < Double(Int64.max) else { return nil }
        return Int64(bytes.rounded())
    }

    /// 解析清理预览底部的汇总行：
    /// `Potential space: 2.93GB | Items: 265 | Categories: 6`（可能是 `At least 2.93GB`）。
    /// 解析不到任何字段时返回 nil。
    static func parseSummary(_ text: String) -> (categories: Int, items: Int, potentialBytes: Int64)? {
        let clean = stripANSI(text)
        let potentialToken = firstCapture(in: clean,
                                        pattern: "Potential space:\\s*(?:At least\\s*)?([0-9]+(?:\\.[0-9]+)?\\s*(?:B|KB|MB|GB|TB))")
        let itemsToken = firstCapture(in: clean, pattern: "Items:\\s*([0-9]+)")
        let categoriesToken = firstCapture(in: clean, pattern: "Categories:\\s*([0-9]+)")
        guard potentialToken != nil || itemsToken != nil || categoriesToken != nil else { return nil }
        return (categories: Int(categoriesToken ?? "") ?? 0,
                items: Int(itemsToken ?? "") ?? 0,
                potentialBytes: potentialToken.flatMap(parseHumanBytes) ?? 0)
    }

    /// 取正则第一个捕获组文本。
    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    /// 从真实清理输出解析「Tracked cleanup: 2.3GB」得到释放字节数；解析不到返回 0。
    static func parseFreedBytes(_ text: String) -> Int64 {
        let clean = stripANSI(text)
        let pattern = "Tracked cleanup:\\s*([0-9]+(?:\\.[0-9]+)?\\s*(?:B|KB|MB|GB|TB))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return 0 }
        let range = NSRange(clean.startIndex..<clean.endIndex, in: clean)
        guard let match = regex.firstMatch(in: clean, options: [], range: range),
              match.numberOfRanges >= 2,
              let valueRange = Range(match.range(at: 1), in: clean) else { return 0 }
        return parseHumanBytes(String(clean[valueRange])) ?? 0
    }
}
