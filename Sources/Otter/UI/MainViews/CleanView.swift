import SwiftUI
import Foundation

// MARK: - 清理分区（ViewModel）
//
// 流程：扫描（只读 dry-run）→ 分类勾选/全选/展开 → 二次确认 → 流式执行 → 结果/通知/错误态。
// 注：原生引擎按勾选条目执行；白名单路径在扫描与删除时都会跳过。
final class CleanViewModel: ObservableObject {
    enum Phase {
        case idle, scanning, previewed, running, done, failed
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lines: [String] = []
    @Published private(set) var plan: CleanPlan?
    @Published private(set) var selected: Set<String> = []
    @Published private(set) var expanded: Set<String> = []
    @Published private(set) var result: CleanResult?
    @Published private(set) var errorText: String?
    @Published private(set) var statusLine: String = ""
    @Published var showConsole = false

    private var didAutoScan = false
    private var didCancelRequested = false

    var serviceReady: Bool { Services.shared.clean != nil }
    var isBusy: Bool { phase == .scanning || phase == .running }

    /// 对外展示「可释放」：优先 potentialBytes，没有则用分类合计。
    var displayBytes: Int64 { plan?.potentialBytes ?? plan?.totalBytes ?? 0 }
    /// 展示条目数：优先摘要求，没有则按分类条目合计。
    var displayItemCount: Int {
        if let items = plan?.summaryItems { return items }
        return plan?.categories.reduce(0) { $0 + $1.items.count } ?? 0
    }
    /// 分类合计与摘要差异较大时给出说明。
    var categorySumDiffersFromSummary: Bool {
        guard let plan = plan, let potential = plan.potentialBytes else { return false }
        return plan.totalBytes > potential + max(1_048_576, potential / 10)
    }

    var scanButtonTitle: String {
        switch phase {
        case .scanning: return "扫描中…"
        case .running: return "执行中…"
        case .previewed, .done, .failed: return "重新扫描"
        case .idle: return "扫描可清理项"
        }
    }

    // MARK: 生命周期

    /// 验收钩子：OTTER_AUTO_SCAN=clean 时进页面自动触发与「扫描」按钮相同的扫描（只读 dry-run）。
    /// 正常使用不自动扫描，首屏保持「未扫描」引导文案，避免误导。
    func autoScanIfRequested() {
        guard !didAutoScan,
              ProcessInfo.processInfo.environment["OTTER_AUTO_SCAN"] == "clean",
              serviceReady, phase == .idle else { return }
        didAutoScan = true
        scan()
    }

    /// 结果页「完成」：回到清理首页（未扫描状态），方便继续逛其他分区。
    func finish() {
        guard !isBusy else { return }
        phase = .idle
        lines = []
        plan = nil
        selected = []
        expanded = []
        result = nil
        errorText = nil
        statusLine = ""
        showConsole = false
    }

    /// 服务未就绪时重试检测（数据层可能在稍后注入）。
    func retryService() {
        objectWillChange.send()
        if serviceReady {
            scan()
        } else {
            errorText = "服务仍未就绪。"
        }
    }

    // MARK: 扫描

    func scan() {
        guard let service = Services.shared.clean else {
            errorText = "清理服务未就绪。"
            return
        }
        phase = .scanning
        lines = []
        plan = nil
        selected = []
        expanded = []
        result = nil
        errorText = nil
        statusLine = "正在扫描，只读预览，不会删除任何文件…"
        showConsole = true

        service.preview(onLine: { [weak self] line in
            DispatchQueue.main.async {
                guard let self = self, self.phase == .scanning else { return }
                self.append(line)
                self.statusLine = line
            }
        }, completion: { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let plan):
                    self.plan = plan
                    let withItems = plan.categories.filter { !$0.items.isEmpty }
                    // 系统缓存需要管理员授权，默认不勾选，避免一进清理就弹密码框。
                    let selectable = withItems.filter { $0.id != "system_caches" }
                    self.selected = Set(selectable.flatMap { cat in cat.items.map { self.key(cat, $0) } })
                    self.expanded = Set(withItems.map { $0.id })
                    self.phase = .previewed
                    if plan.categories.isEmpty {
                        self.statusLine = "没有可清理的项目"
                    } else {
                        let bytes = plan.potentialBytes ?? plan.totalBytes
                        let items = plan.summaryItems ?? plan.categories.reduce(0) { $0 + $1.items.count }
                        self.statusLine = "共 \(plan.categories.count) 类 · \(items) 项 · 预计可释放 \(Fmt.bytes(Double(bytes)))"
                    }
                case .failure(let error):
                    self.phase = .failed
                    self.errorText = "扫描失败：\(error.localizedDescription)"
                    if Prefs.shared.notificationsEnabled {
                        Notifications.shared.postCleanFailed("扫描失败：\(error.localizedDescription)")
                    }
                }
            }
        })
    }

    // MARK: 勾选

    func key(_ category: CleanCategory, _ item: CleanItem) -> String {
        "\(category.id)|\(item.id)"
    }

    func isSelected(_ category: CleanCategory, _ item: CleanItem) -> Bool {
        selected.contains(key(category, item))
    }

    func toggle(_ category: CleanCategory, _ item: CleanItem) {
        let k = key(category, item)
        if selected.contains(k) { selected.remove(k) } else { selected.insert(k) }
    }

    func isCategoryAllSelected(_ category: CleanCategory) -> Bool {
        guard !category.items.isEmpty else { return false }
        return category.items.allSatisfy { selected.contains(key(category, $0)) }
    }

    func isCategoryPartiallySelected(_ category: CleanCategory) -> Bool {
        guard !category.items.isEmpty else { return false }
        let n = category.items.filter { selected.contains(key(category, $0)) }.count
        return n > 0 && n < category.items.count
    }

    func toggleCategory(_ category: CleanCategory) {
        let all = isCategoryAllSelected(category)
        for item in category.items {
            let k = key(category, item)
            if all { selected.remove(k) } else { selected.insert(k) }
        }
    }

    func toggleExpanded(_ category: CleanCategory) {
        if expanded.contains(category.id) { expanded.remove(category.id) } else { expanded.insert(category.id) }
    }

    var allSelected: Bool {
        guard let plan = plan else { return false }
        let items = plan.categories.filter { !$0.items.isEmpty }
        guard !items.isEmpty else { return false }
        return items.allSatisfy { cat in cat.items.allSatisfy { selected.contains(key(cat, $0)) } }
    }

    func toggleAll() {
        guard let plan = plan else { return }
        if allSelected {
            selected = []
        } else {
            let keys = plan.categories.flatMap { cat in cat.items.map { key(cat, $0) } }
            selected = Set(keys)
        }
    }

    func selectedBytes() -> Int64 {
        guard let plan = plan else { return 0 }
        var total: Int64 = 0
        for cat in plan.categories {
            for item in cat.items where selected.contains(key(cat, item)) {
                total += item.bytes
            }
        }
        return total
    }

    func selectedCount() -> Int { selected.count }

    // MARK: 执行

    var confirmMessage: String {
        guard plan != nil else { return "" }
        let hasSystem = selected.contains { $0.hasPrefix("system_caches|") }
        var text = "将直接删除所勾选的 \(selectedCount()) 项，预计释放 \(Fmt.bytes(Double(selectedBytes())))。\n\n此操作不可撤销，确定继续？"
        if hasSystem {
            text += "\n\n系统缓存会请求一次管理员授权。"
        }
        return text
    }

    func run() {
        guard let plan = plan, let service = Services.shared.clean else { return }
        phase = .running
        result = nil
        errorText = nil
        lines = []
        showConsole = true
        statusLine = "正在清理…（\(plan.categories.count) 类）"

        service.run(selected: selected, onProgress: { [weak self] progress in
            DispatchQueue.main.async {
                guard let self = self, self.phase == .running else { return }
                self.statusLine = progress.phase
                self.append(progress.line.isEmpty ? "[\(progress.phase)]" : "[\(progress.phase)] \(progress.line)")
            }
        }, completion: { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let cleanResult):
                    self.phase = .done
                    self.result = cleanResult
                    let tail = cleanResult.output.split(separator: "\n").suffix(60).map(String.init)
                    for line in tail { self.append(line) }
                    let total = cleanResult.freedBytes + cleanResult.trashedBytes
                    if cleanResult.success {
                        if cleanResult.trashedBytes > 0 {
                            self.statusLine = "已移入 Otter 回收站 \(Fmt.bytes(Double(cleanResult.trashedBytes)))，清空后释放"
                        } else {
                            self.statusLine = "清理完成，释放 \(Fmt.bytes(Double(cleanResult.freedBytes)))"
                        }
                    } else {
                        self.statusLine = "清理结束（部分失败）"
                    }
                    if cleanResult.success {
                        Prefs.shared.lastCleanAt = Date().timeIntervalSince1970
                        Prefs.shared.lastCleanBytes = total
                    }
                    if cleanResult.success {
                        let message = cleanResult.trashedBytes > 0
                            ? "已移入 Otter 回收站 \(Fmt.bytes(Double(cleanResult.trashedBytes)))，共 \(self.selectedCount()) 项"
                            : "已释放 \(Fmt.bytes(Double(cleanResult.freedBytes)))，共 \(self.selectedCount()) 项"
                        OperationResultCenter.shared.post(kind: .success, title: "清理完成", message: message)
                    } else {
                        OperationResultCenter.shared.post(kind: .warning, title: "清理结束",
                                                          message: "部分项目未能处理，可在日志中查看原因")
                    }
                    if cleanResult.success, Prefs.shared.notificationsEnabled {
                        if cleanResult.trashedBytes > 0 {
                            Notifications.shared.post(title: "清理完成",
                                                      body: "已移入 Otter 回收站 \(Fmt.bytes(Double(cleanResult.trashedBytes)))")
                        } else {
                            Notifications.shared.postCleanFinished(freedBytes: cleanResult.freedBytes)
                        }
                    }
                case .failure(let error):
                    if self.didCancelRequested {
                        // 用户主动停止，不算失败、不发失败通知。
                        self.didCancelRequested = false
                        self.phase = .previewed
                        self.statusLine = "已停止清理"
                        return
                    }
                    self.phase = .failed
                    self.errorText = "清理失败：\(error.localizedDescription)"
                    if Prefs.shared.notificationsEnabled {
                        Notifications.shared.postCleanFailed("清理失败：\(error.localizedDescription)")
                        OperationResultCenter.shared.post(kind: .error, title: "清理失败",
                                                          message: error.localizedDescription)
                    }
                }
            }
        })
    }

    func cancel() {
        didCancelRequested = true
        Services.shared.clean?.cancel()
        statusLine = "正在停止…"
    }

    // MARK: 私有

    private func append(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lines.append(trimmed)
        if lines.count > 300 { lines.removeFirst(lines.count - 300) }
    }
}

// MARK: - 清理分区（视图）
// 说明：本机工具链只有 CommandLineTools，缺少 SwiftUIMacros 插件，@State 等宏不可用；
// 局部 UI 状态统一放在 ObservableObject 里（@StateObject 是属性包装器，可正常编译）。
final class CleanUIState: ObservableObject {
    @Published var confirmRun = false
}

struct CleanView: View {
    @ObservedObject var model: CleanViewModel
    @StateObject private var ui = CleanUIState()

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "清理",
                          subtitle: "扫描缓存、日志与临时文件；真实清理前会二次确认，可随时停止。") {
                HStack(spacing: 8) {
                    if model.isBusy {
                        ProgressView().controlSize(.small)
                    }
                    Button(model.scanButtonTitle) { model.scan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isBusy || !model.serviceReady)
                }
            }

            if !model.serviceReady {
                ServiceUnavailableView(section: "清理") { model.retryService() }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let error = model.errorText {
                            StatusBanner(kind: .error, title: error, actionTitle: "重试") { model.scan() }
                        }
                        contentForPhase
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
                }
                bottomBar
            }
        }
        .onAppear { model.autoScanIfRequested() }
        .alert("确认清理？", isPresented: $ui.confirmRun) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) { model.run() }
        } message: {
            Text(model.confirmMessage)
        }
    }

    @ViewBuilder
    private var contentForPhase: some View {
        switch model.phase {
        case .idle:
            VStack(spacing: 10) {
                EmptyStateView(icon: "sparkles",
                               title: "点击扫描，预览可清理项",
                               message: "扫描是只读预览，不会立刻删除任何文件；确认计划后才会执行清理。",
                               actionTitle: "扫描可清理项") { model.scan() }
                if let summary = lastCleanSummary {
                    Text(summary)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 320)

        case .scanning:
            PanelCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("正在扫描…").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(model.statusLine)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    ConsoleView(lines: model.lines, height: 220, title: "扫描输出")
                }
            }

        case .previewed:
            previewContent

        case .running:
            PanelCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("正在清理…").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Button("停止") { model.cancel() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Text(model.statusLine).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                    ConsoleView(lines: model.lines, height: 260, title: "执行日志")
                }
            }

        case .done:
            doneContent

        case .failed:
            EmptyStateView(icon: "exclamationmark.triangle",
                           title: "操作未完成",
                           message: model.errorText ?? "请重试。",
                           actionTitle: "重新扫描") { model.scan() }
                .frame(minHeight: 280)
        }
    }

    /// 上次清理摘要（没有记录时返回 nil）。
    private var lastCleanSummary: String? {
        let at = Prefs.shared.lastCleanAt
        guard at > 0 else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日 HH:mm"
        let when = fmt.string(from: Date(timeIntervalSince1970: at))
        return "上次清理：\(when) · 处理 \(Fmt.bytes(Double(Prefs.shared.lastCleanBytes)))"
    }

    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryCard

            if let plan = model.plan, plan.categories.isEmpty {
                EmptyStateView(icon: "leaf",
                               title: "没有可清理的项目",
                               message: "扫描已完成，当前系统没有可清理的缓存、日志或临时文件。稍后可重新扫描。",
                               actionTitle: "重新扫描") { model.scan() }
                    .frame(minHeight: 240)
            } else if let plan = model.plan {
                categoryList(plan)
                if !model.lines.isEmpty {
                    disclosureConsole
                }
            }
        }
    }

    private var summaryCard: some View {
        PanelCard {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("预计可释放")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(Fmt.bytes(Double(model.displayBytes)))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .monospacedDigit()
                }
                Divider().frame(height: 34)
                StatChip(title: "分类", value: "\(model.plan?.categories.count ?? 0)", tint: .primary)
                StatChip(title: "条目", value: "\(model.displayItemCount)", tint: .primary)
                StatChip(title: "已勾选", value: "\(model.selectedCount()) 项", tint: .primary)
                Spacer()
                Button(model.allSelected ? "取消全选" : "全选") { model.toggleAll() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func categoryList(_ plan: CleanPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SubHeader(text: "清理分类", trailing: "共 \(plan.categories.count) 类")
                Spacer()
            }
            VStack(spacing: 6) {
                ForEach(plan.categories) { category in
                    categoryCard(category)
                }
            }
        }
    }

    private func categoryCard(_ category: CleanCategory) -> some View {
        let expanded = model.expanded.contains(category.id)
        return VStack(spacing: 0) {
            HStack(spacing: 9) {
                Toggle("", isOn: Binding(
                    get: { model.isCategoryAllSelected(category) },
                    set: { _ in model.toggleCategory(category) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(category.items.isEmpty)

                Button {
                    model.toggleExpanded(category)
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)
                .disabled(category.items.isEmpty)

                Text(category.title).font(.system(size: 12, weight: .medium))
                Text("\(category.items.count) 项")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                if category.items.isEmpty {
                    Text("无可清理")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                } else {
                    Text(Fmt.bytes(Double(category.bytes)))
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(model.isCategoryAllSelected(category) ? Color.primary : Color.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .onTapGesture { if !category.items.isEmpty { model.toggleExpanded(category) } }

            if expanded && !category.items.isEmpty {
                Divider().padding(.horizontal, 12)
                VStack(spacing: 0) {
                    ForEach(category.items) { item in
                        HStack(spacing: 9) {
                            Toggle("", isOn: Binding(
                                get: { model.isSelected(category, item) },
                                set: { _ in model.toggle(category, item) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            Text(item.label)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            Text(Fmt.bytes(Double(item.bytes)))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                        .onTapGesture { model.toggle(category, item) }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var disclosureConsole: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                model.showConsole.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: model.showConsole ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("扫描日志（\(model.lines.count) 行）").font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            if model.showConsole {
                ConsoleView(lines: model.lines, height: 150, title: "扫描输出")
            }
        }
    }

    private var doneContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatusBanner(kind: model.result?.success == true ? .success : .warning,
                         title: model.statusLine,
                         message: model.result?.success == true
                            ? ((model.result?.trashedBytes ?? 0) > 0
                                ? "已移入 Otter 回收站，可在「设置 → Otter 回收站」恢复；清空后释放磁盘。"
                                : "已清理的项目不可恢复；菜单栏与 HUD 指标不受影响。")
                            : "任务结束，但引擎返回了非成功状态，请查看执行日志。")
            if let result = model.result, !result.output.isEmpty {
                ConsoleView(lines: result.output.split(separator: "\n").suffix(80).map(String.init),
                            height: 220, title: "清理结果")
            }
            HStack(spacing: 10) {
                Button("完成") { model.finish() }
                    .buttonStyle(.bordered)
                Button("再次扫描") { model.scan() }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if model.phase == .previewed, let plan = model.plan, !plan.categories.isEmpty {
            BottomBar {
                Text("已选 \(model.selectedCount()) 项 · 预计释放 \(Fmt.bytes(Double(model.selectedBytes())))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("原生引擎 · 按勾选执行")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Button("清理…") { ui.confirmRun = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(model.isBusy)
            }
        } else if model.phase == .running {
            BottomBar {
                Text(model.statusLine).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Button("停止") { model.cancel() }
                    .buttonStyle(.bordered)
            }
        }
    }
}