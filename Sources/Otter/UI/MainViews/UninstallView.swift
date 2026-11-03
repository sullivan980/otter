import SwiftUI
import AppKit

// MARK: - 卸载分区（ViewModel）
//
// 应用列表（搜索/排序/图标）→ 选中自动扫描残留 → 分类勾选 → 二次确认 → 移入废纸篓 → 结果。
final class UninstallViewModel: ObservableObject {
    @Published private(set) var apps: [AppItem] = []
    @Published private(set) var isLoadingApps = false
    @Published private(set) var appError: String?
    @Published private(set) var icons: [String: NSImage] = [:]

    @Published var query: String = ""
    @Published var sortAscending: Bool = true
    @Published var sortBySize: Bool = false
    @Published private(set) var appSizes: [String: Int64] = [:]
    @Published private(set) var isComputingSizes = false

    @Published private(set) var selectedApp: AppItem?
    @Published private(set) var scan: UninstallScan?
    @Published private(set) var isScanning = false
    @Published private(set) var isTrashing = false
    @Published private(set) var selectedIds: Set<String> = []
    @Published private(set) var expandedKinds: Set<String> = []
    @Published private(set) var errorText: String?
    @Published private(set) var resultMessage: String?

    private var didLoad = false
    private var didAutoScan = false
    private var autoScanPending = false

    var serviceReady: Bool { Services.shared.uninstall != nil }

    /// 分类展示顺序与中文名。
    static let kindOrder = ["app", "cache", "prefs", "data", "state", "logs", "other"]
    static let kindNames: [String: String] = [
        "app": "应用本体", "cache": "缓存", "prefs": "偏好设置",
        "data": "数据", "state": "状态", "logs": "日志", "other": "其他"
    ]
    static func kindName(_ kind: String) -> String { kindNames[kind] ?? kind }
    static func kindColor(_ kind: String) -> Color {
        switch kind {
        case "app": return .accentColor
        case "cache": return .orange
        case "prefs": return .blue
        case "data": return .purple
        case "state": return .teal
        case "logs": return .gray
        default: return .secondary
        }
    }

    // MARK: 应用列表

    func loadAppsIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        loadApps()
    }

    func loadApps() {
        guard let service = Services.shared.uninstall else {
            appError = "卸载服务未就绪。"
            return
        }
        isLoadingApps = true
        appError = nil
        service.listApps { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingApps = false
                switch result {
                case .success(let apps):
                    self.apps = apps
                    self.computeAppSizes(apps)
                    self.runPendingAutoScan()
                case .failure(let error):
                    self.appError = "加载应用列表失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func retryService() {
        objectWillChange.send()
        if serviceReady {
            didLoad = false
            loadAppsIfNeeded()
        } else {
            appError = "服务仍未就绪。"
        }
    }

    /// 验收钩子：OTTER_AUTO_SCAN=uninstall 时自动加载应用并扫描第一个应用的残留（只读，不删除）。
    func autoScanIfRequested() {
        guard ProcessInfo.processInfo.environment["OTTER_AUTO_SCAN"] == "uninstall", !didAutoScan else { return }
        autoScanPending = true
        if !apps.isEmpty { runPendingAutoScan() }
    }

    private func computeAppSizes(_ apps: [AppItem]) {
        appSizes = [:]
        isComputingSizes = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let sizes = apps.map { app in
                (app.id, SpaceScanner.allocatedSize(of: URL(fileURLWithPath: app.path)))
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.appSizes = Dictionary(uniqueKeysWithValues: sizes)
                self.isComputingSizes = false
            }
        }
    }

    private func runPendingAutoScan() {
        guard autoScanPending, !didAutoScan else { return }
        didAutoScan = true
        autoScanPending = false
        if let first = filteredApps.first { select(first) }
    }

    var filteredApps: [AppItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var list = q.isEmpty ? apps : apps.filter {
            $0.name.lowercased().contains(q) || $0.path.lowercased().contains(q)
        }
        list.sort { a, b in
            if sortBySize {
                return (appSizes[a.id] ?? 0) > (appSizes[b.id] ?? 0)
            }
            let r = a.name.localizedStandardCompare(b.name)
            return sortAscending ? r == .orderedAscending : r == .orderedDescending
        }
        return list
    }

    func icon(for app: AppItem) -> NSImage? { icons[app.path] }

    func loadIconIfNeeded(_ app: AppItem) {
        guard icons[app.path] == nil else { return }
        let path = app.path
        DispatchQueue.global(qos: .utility).async {
            let image = NSWorkspace.shared.icon(forFile: path)
            DispatchQueue.main.async {
                self.icons[path] = image
            }
        }
    }

    // MARK: 选择应用 / 扫描残留

    func select(_ app: AppItem) {
        if selectedApp?.id == app.id && scan != nil { return }
        selectedApp = app
        scan = nil
        errorText = nil
        resultMessage = nil
        selectedIds = []
        expandedKinds = []
        guard let service = Services.shared.uninstall else {
            errorText = "卸载服务未就绪。"
            return
        }
        isScanning = true
        service.scan(app) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // 用户可能已切到别的应用，忽略过期结果
                guard self.selectedApp?.id == app.id else { return }
                self.isScanning = false
                switch result {
                case .success(let scan):
                    self.scan = scan
                    self.selectedIds = Set(scan.leftovers.map { $0.id })
                    self.expandedKinds = Set(scan.leftovers.map { $0.kind })
                case .failure(let error):
                    self.errorText = "扫描残留失败：\(error.localizedDescription)"
                    if Prefs.shared.notificationsEnabled {
                        Notifications.shared.postUninstallFailed(app: app.name,
                                                                 reason: "扫描残留失败：\(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func rescan() {
        guard let app = selectedApp else { return }
        let keep = app
        selectedApp = nil
        select(keep)
    }

    // MARK: 勾选

    func isSelected(_ item: LeftoverItem) -> Bool { selectedIds.contains(item.id) }

    func toggle(_ item: LeftoverItem) {
        if selectedIds.contains(item.id) { selectedIds.remove(item.id) } else { selectedIds.insert(item.id) }
    }

    func isKindAllSelected(_ kind: String) -> Bool {
        guard let items = scan?.leftovers.filter({ $0.kind == kind }), !items.isEmpty else { return false }
        return items.allSatisfy { selectedIds.contains($0.id) }
    }

    func toggleKind(_ kind: String) {
        guard let items = scan?.leftovers.filter({ $0.kind == kind }), !items.isEmpty else { return }
        let all = isKindAllSelected(kind)
        for item in items {
            if all { selectedIds.remove(item.id) } else { selectedIds.insert(item.id) }
        }
    }

    var allSelected: Bool {
        guard let scan = scan, !scan.leftovers.isEmpty else { return false }
        return scan.leftovers.allSatisfy { selectedIds.contains($0.id) }
    }

    func toggleAll() {
        guard let scan = scan else { return }
        if allSelected {
            selectedIds = []
        } else {
            selectedIds = Set(scan.leftovers.map { $0.id })
        }
    }

    func selectedBytes() -> Int64 {
        guard let scan = scan else { return 0 }
        return scan.leftovers.filter { selectedIds.contains($0.id) }.reduce(Int64(0)) { $0 + $1.bytes }
    }

    /// 按分类分组（固定顺序）。
    func groupedLeftovers() -> [(kind: String, items: [LeftoverItem])] {
        guard let scan = scan else { return [] }
        var buckets: [String: [LeftoverItem]] = [:]
        for item in scan.leftovers {
            let kind = Self.kindOrder.contains(item.kind) ? item.kind : "other"
            buckets[kind, default: []].append(item)
        }
        var result: [(String, [LeftoverItem])] = []
        for kind in Self.kindOrder {
            if let items = buckets[kind], !items.isEmpty {
                result.append((kind, items.sorted { $0.bytes > $1.bytes }))
            }
        }
        return result
    }

    func toggleExpanded(_ kind: String) {
        if expandedKinds.contains(kind) { expandedKinds.remove(kind) } else { expandedKinds.insert(kind) }
    }

    func clearResult() { resultMessage = nil }

    // MARK: 执行卸载

    func trashSelected() {
        guard let service = Services.shared.uninstall, let scan = scan else { return }
        let items = scan.leftovers.filter { selectedIds.contains($0.id) }
        guard !items.isEmpty else { return }
        isTrashing = true
        errorText = nil
        let bytes = items.reduce(Int64(0)) { $0 + $1.bytes }
        service.trash(items) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isTrashing = false
                switch result {
                case .success(let count):
                    let moved = count > 0 ? count : items.count
                    self.resultMessage = "已将 \(moved) 项移入废纸篓，可从废纸篓还原。"
                    self.selectedApp = nil
                    self.scan = nil
                    self.selectedIds = []
                    self.expandedKinds = []
                    OperationResultCenter.shared.post(kind: .success, title: "卸载完成",
                                                      message: "\(scan.app.name)：已将 \(moved) 项移入废纸篓，可从废纸篓还原")
                    CleanHistoryStore.shared.add(kind: "uninstall", freedBytes: 0,
                                                 trashedBytes: bytes, items: moved,
                                                 note: scan.app.name)
                    if Prefs.shared.notificationsEnabled {
                        Notifications.shared.postUninstallFinished(app: scan.app.name, bytes: bytes)
                    }
                    self.didLoad = false
                    self.loadApps()
                case .failure(let error):
                    self.errorText = "卸载失败：\(error.localizedDescription)"
                    if Prefs.shared.notificationsEnabled {
                        Notifications.shared.postUninstallFailed(app: scan.app.name,
                                                                 reason: "卸载失败：\(error.localizedDescription)")
                        OperationResultCenter.shared.post(kind: .error, title: "卸载失败",
                                                          message: "(scan.app.name)：(error.localizedDescription)")
                    }
                }
            }
        }
    }

    var confirmMessage: String {
        guard let app = selectedApp else { return "" }
        return "确定移除「\(app.name)」的 \(selectedIds.count) 项文件吗？\n\n合计 \(Fmt.bytes(Double(selectedBytes())))，将移入废纸篓（可还原）。应用数据删除后无法恢复。"
    }
}

// MARK: - 卸载分区（视图）
// 局部 UI 状态放 ObservableObject（本机无 SwiftUIMacros，不能用 @State）。
final class UninstallUIState: ObservableObject {
    @Published var confirmTrash = false
}

struct UninstallView: View {
    @ObservedObject var model: UninstallViewModel
    @StateObject private var ui = UninstallUIState()

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: L("卸载", "Uninstall"),
                          subtitle: L("彻底移除应用本体与残留文件；默认移入废纸篓，可随时还原。",
                                      "Remove apps and leftovers. Items go to Trash by default and can be restored.")) {
                HStack(spacing: 8) {
                    if model.isLoadingApps || model.isScanning || model.isTrashing {
                        ProgressView().controlSize(.small)
                    }
                    Button("刷新列表") { model.loadApps() }
                        .buttonStyle(.bordered)
                        .disabled(model.isLoadingApps || !model.serviceReady)
                }
            }

            if !model.serviceReady {
                ServiceUnavailableView(section: "卸载") { model.retryService() }
            } else {
                HStack(spacing: 0) {
                    appList
                    Divider()
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            model.loadAppsIfNeeded()
            model.autoScanIfRequested()
        }
        .alert("确认卸载？", isPresented: $ui.confirmTrash) {
            Button("取消", role: .cancel) {}
            Button("移入废纸篓", role: .destructive) { model.trashSelected() }
        } message: {
            Text(model.confirmMessage)
        }
    }

    // MARK: 左侧应用列表

    private var appList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SearchField(placeholder: "搜索应用…", text: Binding(
                get: { model.query },
                set: { model.query = $0 }
            ))
            .padding(.horizontal, 14)
            .padding(.top, 2)

            HStack(spacing: 8) {
                Text("\(model.filteredApps.count) 个应用")
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("名称 A → Z") { model.sortBySize = false; model.sortAscending = true }
                    Button("名称 Z → A") { model.sortBySize = false; model.sortAscending = false }
                    Button("按体积（大 → 小）") { model.sortBySize = true }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.arrow.down").font(.system(size: 9))
                        Text(model.sortBySize ? "体积" : (model.sortAscending ? "A→Z" : "Z→A"))
                            .font(.system(size: 10.5))
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 64)
            }
            .padding(.horizontal, 14)

            if let error = model.appError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
            }

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.filteredApps) { app in
                        appRow(app)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
            .overlay {
                if model.isLoadingApps && model.apps.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("加载应用列表…").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                } else if !model.isLoadingApps && model.filteredApps.isEmpty && model.appError == nil {
                    Text(model.query.isEmpty ? "未找到应用" : "没有匹配的应用")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 268)
    }

    private func appRow(_ app: AppItem) -> some View {
        let selected = model.selectedApp?.id == app.id
        return Button {
            model.select(app)
        } label: {
            HStack(spacing: 8) {
                appIcon(app, size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                    Text(app.bundleId ?? app.path)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
                if let size = model.appSizes[app.id] {
                    Text(Fmt.bytes(Double(size)))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .onAppear { model.loadIconIfNeeded(app) }
    }

    @ViewBuilder
    private func appIcon(_ app: AppItem, size: CGFloat) -> some View {
        if let image = model.icon(for: app) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                Text(String(app.name.prefix(1)))
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        }
    }

    // MARK: 右侧详情

    private var detail: some View {
        ZStack {
            if !model.serviceReady {
                EmptyView()
            } else if let message = model.resultMessage {
                VStack(spacing: 14) {
                    StatusBanner(kind: .success, title: message,
                                 message: "列表已刷新。若应用本体仍在，可在访达中手动移除。")
                    Button("继续卸载其他应用") {
                        model.clearResult()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let app = model.selectedApp {
                detailForApp(app)
            } else {
                EmptyStateView(icon: "xmark.bin",
                               title: "选择一个应用",
                               message: "从左侧选择要卸载的应用，Otter 会扫描它的应用本体、缓存、偏好、日志与数据文件。")
            }
        }
    }

    private func detailForApp(_ app: AppItem) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    appHeader(app)

                    if let error = model.errorText {
                        StatusBanner(kind: .error, title: error, actionTitle: "重新扫描") { model.rescan() }
                    }

                    if model.isScanning {
                        PanelCard {
                            HStack(spacing: 9) {
                                ProgressView().controlSize(.small)
                                Text("正在扫描关联文件…").font(.system(size: 12, weight: .semibold))
                                Spacer()
                            }
                        }
                    } else if let scan = model.scan {
                        if scan.leftovers.isEmpty {
                            StatusBanner(kind: .info,
                                         title: "未发现关联残留",
                                         message: "该应用没有可清理的残留文件，Otter 只处理扫描出的项目。")
                        } else {
                            leftoversSection(scan)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }

            if model.scan != nil && !model.isScanning {
                BottomBar {
                    Text("已选 \(model.selectedIds.count) 项 · 共 \(Fmt.bytes(Double(model.selectedBytes())))")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    Spacer()
                    Button(model.allSelected ? "取消全选" : "全选") { model.toggleAll() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("移入废纸篓…") { ui.confirmTrash = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(model.selectedIds.isEmpty || model.isTrashing)
                }
            }
        }
    }

    private func appHeader(_ app: AppItem) -> some View {
        HStack(alignment: .center, spacing: 14) {
            appIcon(app, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.system(size: 17, weight: .semibold))
                Text(app.path)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
                    if let bundleId = app.bundleId {
                        KindTag(text: bundleId, color: .secondary)
                    }
                    if let scan = model.scan {
                        Text("残留 \(scan.leftovers.count) 项 · \(Fmt.bytes(Double(scan.totalBytes)))")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                model.rescan()
            } label: {
                Label("重新扫描", systemImage: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.isScanning)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private func leftoversSection(_ scan: UninstallScan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SubHeader(text: "关联文件", trailing: "\(scan.leftovers.count) 项 · \(Fmt.bytes(Double(scan.totalBytes)))")
            VStack(spacing: 6) {
                ForEach(model.groupedLeftovers(), id: \.kind) { group in
                    kindCard(kind: group.kind, items: group.items)
                }
            }
            Text("默认移入废纸篓，误删可从废纸篓还原；应用数据删除后无法恢复。")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
    }

    private func kindCard(kind: String, items: [LeftoverItem]) -> some View {
        let expanded = model.expandedKinds.contains(kind)
        let bytes = items.reduce(Int64(0)) { $0 + $1.bytes }
        return VStack(spacing: 0) {
            HStack(spacing: 9) {
                Toggle("", isOn: Binding(
                    get: { model.isKindAllSelected(kind) },
                    set: { _ in model.toggleKind(kind) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()

                Button {
                    model.toggleExpanded(kind)
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                KindTag(text: UninstallViewModel.kindName(kind), color: UninstallViewModel.kindColor(kind))
                Text("\(items.count) 项").font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer()
                Text(Fmt.bytes(Double(bytes)))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .onTapGesture { model.toggleExpanded(kind) }

            if expanded {
                Divider().padding(.horizontal, 12)
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        HStack(spacing: 9) {
                            Toggle("", isOn: Binding(
                                get: { model.isSelected(item) },
                                set: { _ in model.toggle(item) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            VStack(alignment: .leading, spacing: 1) {
                                Text((item.path as NSString).lastPathComponent)
                                    .font(.system(size: 11.5))
                                    .lineLimit(1)
                                Text(item.path)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 8)
                            Text(Fmt.bytes(Double(item.bytes)))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                        .onTapGesture { model.toggle(item) }
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
}