import SwiftUI
import AppKit
import Foundation

// MARK: - 磁盘分区（只读扫描）
//
// 选择目录 → 后台只读遍历 → 按大小列出大目录/大文件 → 面包屑下钻/返回。
// 严格只读：不提供任何删除/移动入口，避免误操作。
struct DiskEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let isDir: Bool
    let bytes: Int64
}

final class DiskViewModel: ObservableObject {
    enum ViewMode: String, CaseIterable, Identifiable {
        case items = "项目"
        case largeFiles = "大文件"
        case duplicates = "重复文件"
        var id: String { rawValue }
    }

    @Published private(set) var scannedPath: String = ""
    @Published private(set) var breadcrumb: [String] = []
    @Published private(set) var isScanning = false
    /// 是否至少完成过一次扫描：用于区分「未扫描」与「扫描后为空」的首屏文案。
    @Published private(set) var hasScanned = false
    @Published private(set) var progressText = ""
    @Published private(set) var entries: [DiskEntry] = []
    @Published private(set) var largeFiles: [DiskEntry] = []
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var totalFiles = 0
    @Published private(set) var truncated = false
    @Published private(set) var errorText: String?
    @Published var viewMode: ViewMode = .items
    @Published var largeFileThreshold: Int64 = 20 * 1024 * 1024
    @Published private(set) var duplicateGroups: [DuplicateGroup] = []
    @Published private(set) var isScanningDuplicates = false
    @Published private(set) var duplicateProgress = ""
    @Published var expandedDuplicates: Set<String> = []

    /// 上限：避免扫全盘时无限跑（按“文件数”截断，并显式提示结果不完整）。
    let maxFiles = 400_000
    private let lock = NSLock()
    private var generationValue = 0
    private var didAutoStart = false

    init() {
        let env = ProcessInfo.processInfo.environment["OTTER_DISK_PATH"]
        let start = env?.isEmpty == false ? env! : NSHomeDirectory()
        scannedPath = start
        breadcrumb = [start]
    }

    // MARK: 控件动作

    func autoStartIfNeeded() {
        guard !didAutoStart else { return }
        didAutoStart = true
        let env = ProcessInfo.processInfo.environment["OTTER_DISK_PATH"]
        if let path = env, !path.isEmpty {
            scan(path)
        }
    }

    func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "扫描"
        panel.message = "选择要分析的目录（只读扫描，不会修改任何文件）"
        if !scannedPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: (scannedPath as NSString).expandingTildeInPath)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        breadcrumb = [url.standardizedFileURL.path]
        scan(url.path)
    }

    func setQuick(_ path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        breadcrumb = [expanded]
        scan(expanded)
    }

    func rescan() {
        guard !scannedPath.isEmpty else { return }
        scan(scannedPath)
    }

    func drill(_ entry: DiskEntry) {
        guard entry.isDir else { return }
        breadcrumb.append(entry.path)
        scan(entry.path)
    }

    func goUp() {
        if breadcrumb.count > 1 {
            breadcrumb.removeLast()
            scan(breadcrumb[breadcrumb.count - 1])
        } else {
            let parent = (scannedPath as NSString).deletingLastPathComponent
            guard !parent.isEmpty, parent != scannedPath else { return }
            breadcrumb = [parent]
            scan(parent)
        }
    }

    func jump(to index: Int) {
        guard index >= 0 && index < breadcrumb.count else { return }
        breadcrumb = Array(breadcrumb.prefix(index + 1))
        scan(breadcrumb[index])
    }

    /// 当前目录的父级路径（仅用于展示）。
    var parentPath: String {
        scannedPath.isEmpty ? "" : (scannedPath as NSString).deletingLastPathComponent
    }

    // MARK: 扫描

    func scanDuplicates() {
        guard !scannedPath.isEmpty, !isScanningDuplicates else { return }
        isScanningDuplicates = true
        duplicateGroups = []
        duplicateProgress = "准备扫描…"
        let root = scannedPath
        let gen = generationValue + 1
        generationValue = gen
        DuplicateScanner.scan(root: URL(fileURLWithPath: root), progress: { [weak self] line in
            DispatchQueue.main.async {
                guard let self = self, self.generationValue == gen else { return }
                self.duplicateProgress = line
            }
        }, isCancelled: { [weak self] in
            guard let self = self else { return true }
            return self.generationValue != gen
        }, completion: { [weak self] groups in
            guard let self = self, self.generationValue == gen else { return }
            self.isScanningDuplicates = false
            self.duplicateGroups = groups
            self.duplicateProgress = ""
        })
    }

    func trashDuplicates(_ group: DuplicateGroup) {
        let rest = Array(group.files.dropFirst())
        guard !rest.isEmpty else { return }
        let moved = SafeTrashService.shared.move(rest)
        duplicateGroups.removeAll { $0.id == group.id }
        OperationResultCenter.shared.post(kind: moved.errors.isEmpty ? .success : .warning,
                                          title: "重复文件已处理",
                                          message: "移入 Otter 回收站 \(moved.moved) 个副本（\(Fmt.bytes(Double(moved.bytes)))）")
    }

    func scan(_ path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue else {
            errorText = "目录不存在或不可读取：\(expanded)"
            return
        }
        let url = URL(fileURLWithPath: expanded).standardizedFileURL
        let generation = nextGeneration()
        scannedPath = url.path
        isScanning = true
        errorText = nil
        entries = []
        largeFiles = []
        duplicateGroups = []
        duplicateProgress = ""
        totalBytes = 0
        totalFiles = 0
        truncated = false
        progressText = "准备扫描…"
        viewMode = .items
        let threshold = largeFileThreshold

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let result = Self.walk(url: url, limit: self.maxFiles, threshold: threshold,
                                   isCancelled: { !self.isCurrent(generation) }) { files, bytes in
                DispatchQueue.main.async {
                    guard self.isCurrent(generation), self.isScanning else { return }
                    self.totalFiles = files
                    self.totalBytes = bytes
                    self.progressText = "已扫描 \(files) 个文件 · \(Fmt.bytes(Double(bytes)))"
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.isCurrent(generation) else { return }
                self.isScanning = false
                self.hasScanned = true
                self.entries = result.entries
                self.largeFiles = result.largeFiles
                self.totalBytes = result.totalBytes
                self.totalFiles = result.totalFiles
                self.truncated = result.truncated
                self.errorText = result.error
                self.progressText = result.entries.isEmpty ? "该目录为空" : "扫描完成"
            }
        }
    }

    private func nextGeneration() -> Int {
        lock.lock()
        defer { lock.unlock() }
        generationValue += 1
        return generationValue
    }

    private func isCurrent(_ generation: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generationValue == generation
    }

    // MARK: 遍历（后台线程；只读）

    private struct Agg {
        var isDir: Bool = false
        var bytes: Int64 = 0
    }

    struct WalkResult {
        var entries: [DiskEntry] = []
        var largeFiles: [DiskEntry] = []
        var totalBytes: Int64 = 0
        var totalFiles: Int = 0
        var truncated = false
        var error: String?
    }

    static func walk(url: URL,
                             limit: Int,
                             threshold: Int64 = 20 * 1024 * 1024,
                             isCancelled: () -> Bool,
                             onProgress: @escaping (Int, Int64) -> Void) -> WalkResult {
        var result = WalkResult()
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey,
                                      .fileSizeKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
                                      .fileResourceIdentifierKey, .linkCountKey]
        var firstError: String?

        guard let enumerator = fm.enumerator(at: url,
                                             includingPropertiesForKeys: keys,
                                             options: [],
                                             errorHandler: { url, error in
                                                 if firstError == nil {
                                                     firstError = "部分目录不可读：\(url.lastPathComponent)（\(error.localizedDescription)）"
                                                 }
                                                 return true
                                             }) else {
            result.error = "无法读取目录：\(url.path)"
            return result
        }

        var aggregates: [String: Agg] = [:]
        var large: [DiskEntry] = []
        var seenInodes = Set<String>()
        let rootPath = url.path
        let prefixCount = rootPath.hasSuffix("/") ? rootPath.count : rootPath.count + 1
        var totalBytes: Int64 = 0
        var fileCount = 0
        var scannedCount = 0
        var truncated = false

        while let item = enumerator.nextObject() as? URL {
            scannedCount += 1
            if scannedCount % 512 == 0 {
                if isCancelled() { return result }
                onProgress(fileCount, totalBytes)
            }
            if fileCount >= limit {
                truncated = true
                break
            }
            guard item.path.count > prefixCount else { continue }
            let relative = String(item.path.dropFirst(prefixCount))
            guard let firstComponent = relative.split(separator: "/").first.map(String.init),
                  !firstComponent.isEmpty else { continue }

            let values = try? item.resourceValues(forKeys: Set(keys))
            if values?.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            let isDir = values?.isDirectory ?? false
            var size: Int64 = 0
            if !isDir {
                // 只统计实际占用：iCloud 未下载/稀疏文件逻辑大小可能远超磁盘，
                // 用 allocated size 才能和「磁盘已用」对得上。
                size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)

                // 硬链接只算一次（同一个 inode 可能出现在多个路径）。
                if let linkCount = values?.linkCount, linkCount > 1,
                   let inode = values?.fileResourceIdentifier {
                    let key = String(describing: inode)
                    if seenInodes.contains(key) { continue }
                    seenInodes.insert(key)
                }
                totalBytes += size
                fileCount += 1
            }

            var agg = aggregates[firstComponent] ?? Agg(isDir: isDir, bytes: 0)
            if isDir { agg.isDir = true }
            agg.bytes += size
            aggregates[firstComponent] = agg

            if !isDir, size >= threshold, large.count < 4000 {
                large.append(DiskEntry(id: item.path, name: item.lastPathComponent,
                                       path: item.path, isDir: false, bytes: size))
            }
        }

        if isCancelled() { return result }

        result.totalBytes = totalBytes
        result.totalFiles = fileCount
        result.truncated = truncated
        result.error = firstError
        result.entries = aggregates.map { name, agg in
            let path = rootPath.hasSuffix("/") ? rootPath + name : rootPath + "/" + name
            return DiskEntry(id: path, name: name, path: path, isDir: agg.isDir, bytes: agg.bytes)
        }
        .filter { $0.bytes > 0 }
        .sorted { $0.bytes > $1.bytes }
        result.largeFiles = large.sorted { $0.bytes > $1.bytes }.prefix(200).map { $0 }
        onProgress(fileCount, totalBytes)
        return result
    }
}

// MARK: - 磁盘分区（视图）
struct DiskView: View {
    @ObservedObject var model: DiskViewModel

    private let quickPaths: [(String, String)] = [
        ("主目录", "~"), ("下载", "~/Downloads"), ("文稿", "~/Documents"),
        ("桌面", "~/Desktop"), ("应用程序", "/Applications"), ("资源库", "~/Library")
    ]

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: L("磁盘", "Disk"),
                          subtitle: L("只读分析目录占用，按大小找出大文件与大目录，可逐层下钻；不会删除或移动任何文件。",
                                      "Read-only usage analysis. Find large files and folders and drill down; nothing is deleted or moved.")) {
                HStack(spacing: 8) {
                    if model.isScanning {
                        ProgressView().controlSize(.small)
                    }
                    Button("选择目录…") { model.chooseDirectory() }
                        .buttonStyle(.bordered)
                    Button(model.isScanning ? "扫描中…" : "扫描") { model.rescan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isScanning || model.scannedPath.isEmpty)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                pathBar
                breadcrumbBar
                if model.isScanning {
                    scanningBanner
                }
                if let error = model.errorText {
                    StatusBanner(kind: .warning, title: error)
                }
                if model.truncated && !model.isScanning {
                    StatusBanner(kind: .info, title: "结果可能不完整",
                                 message: "已达到 \(model.maxFiles) 个文件的扫描上限；可先进入子目录再扫描。")
                }
                if !model.entries.isEmpty && !model.isScanning {
                    summaryBar
                }
                listArea
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear { model.autoStartIfNeeded() }
    }

    private var pathBar: some View {
        PanelCard(padding: 12) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                    Text(model.scannedPath.isEmpty ? "未选择目录" : model.scannedPath)
                        .font(.system(size: 11.5, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    if model.isScanning {
                        Text(model.progressText)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 6) {
                    Text("快捷").font(.system(size: 10)).foregroundStyle(.tertiary)
                    ForEach(quickPaths, id: \.1) { item in
                        Button(item.0) { model.setQuick(item.1) }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                    }
                }
            }
        }
    }

    private var breadcrumbBar: some View {
        HStack(spacing: 6) {
            Button {
                model.goUp()
            } label: {
                Label("上一级", systemImage: "arrow.up.left")
                    .font(.system(size: 10.5))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.isScanning)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(model.breadcrumb.enumerated()), id: \.offset) { index, path in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        let isLast = index == model.breadcrumb.count - 1
                        Button {
                            model.jump(to: index)
                        } label: {
                            Text(displayName(path))
                                .font(.system(size: 10.5, weight: isLast ? .semibold : .regular))
                                .foregroundStyle(isLast ? Color.primary : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isScanning)
                    }
                }
            }
            Spacer(minLength: 8)
            Text("父级：\(model.parentPath)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func displayName(_ path: String) -> String {
        if path == NSHomeDirectory() { return "~" }
        if path.hasPrefix(NSHomeDirectory() + "/") {
            return String(path.dropFirst(NSHomeDirectory().count + 1))
        }
        return (path as NSString).lastPathComponent.isEmpty ? path : (path as NSString).lastPathComponent
    }

    private var scanningBanner: some View {
        PanelCard(padding: 12) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text("正在只读扫描…").font(.system(size: 11.5, weight: .semibold))
                    Text(model.progressText).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("扫描期间可继续操作其他分区").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 18) {
            StatChip(title: "总计", value: Fmt.bytes(Double(model.totalBytes)), tint: .primary)
            StatChip(title: "文件", value: "\(model.totalFiles)", tint: .primary)
            StatChip(title: "项目", value: "\(model.entries.count)", tint: .primary)
            Spacer()
            Picker("", selection: Binding(
                get: { model.viewMode },
                set: { mode in
                    model.viewMode = mode
                    if mode == .duplicates && model.duplicateGroups.isEmpty && !model.isScanningDuplicates {
                        model.scanDuplicates()
                    }
                }
            )) {
                ForEach(DiskViewModel.ViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 230)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var listArea: some View {
        if !model.hasScanned && !model.isScanning && model.errorText == nil {
            // 首屏：还没扫描过 —— 明确引导，不能误导成「空目录」。
            EmptyStateView(icon: "internaldrive",
                           title: "选择目录开始分析",
                           message: "选择目录或点击右上角「扫描」，按大小查看大文件与大目录。只读扫描，不会删除或移动任何文件。",
                           actionTitle: "扫描当前目录") { model.rescan() }
                .frame(maxHeight: .infinity)
        } else if !model.isScanning && model.entries.isEmpty && model.errorText == nil {
            // 扫描完成但确实为空（或全是 0 字节项目）。
            EmptyStateView(icon: "folder",
                           title: "该目录没有可显示的项目",
                           message: "该目录为空，或没有可统计大小的项目。可返回上一级或换一个目录。",
                           actionTitle: "重新扫描") { model.rescan() }
                .frame(maxHeight: .infinity)
        } else if model.entries.isEmpty && model.isScanning {
            EmptyStateView(icon: "hourglass",
                           title: "正在扫描…",
                           message: "大目录可能需要一些时间，可继续操作其他分区。")
                .frame(maxHeight: .infinity)
        } else {
            if model.viewMode == .duplicates {
                duplicatesList
            } else {
                if model.viewMode == .largeFiles {
                    HStack(spacing: 8) {
                        Text("阈值").font(.system(size: 10.5)).foregroundStyle(.secondary)
                        Menu(Fmt.bytes(Double(model.largeFileThreshold))) {
                            ForEach([20, 100, 500, 1024], id: \.self) { mb in
                                Button("\(mb) MB") {
                                    model.largeFileThreshold = Int64(mb) * 1024 * 1024
                                    model.rescan()
                                }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 90)
                        Spacer()
                        Text("扫描时收集，修改阈值会重新扫描").font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                }
                ScrollView {
                    LazyVStack(spacing: 3) {
                        if model.viewMode == .items {
                            ForEach(model.entries) { entry in
                                entryRow(entry)
                            }
                        } else {
                            if model.largeFiles.isEmpty {
                                Text("未发现大于 \(Fmt.bytes(Double(model.largeFileThreshold))) 的单个文件")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 18)
                            } else {
                                ForEach(model.largeFiles) { entry in
                                    entryRow(entry)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var duplicatesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isScanningDuplicates {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(model.duplicateProgress).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            } else if model.duplicateGroups.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.hasScanned ? "未发现重复文件" : "先扫描目录")
                        .font(.system(size: 11.5, weight: .medium))
                    Button("开始查重") { model.scanDuplicates() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.duplicateGroups) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 10) {
                                    Text(Fmt.bytes(Double(group.size)))
                                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                    Text("\(group.files.count) 个副本")
                                        .font(.system(size: 10.5)).foregroundStyle(.secondary)
                                    Text("可释放 \(Fmt.bytes(Double(group.wastedBytes)))")
                                        .font(.system(size: 10.5)).foregroundStyle(.orange)
                                    Spacer()
                                    Button(model.expandedDuplicates.contains(group.id) ? "收起路径" : "查看路径") {
                                        if model.expandedDuplicates.contains(group.id) {
                                            model.expandedDuplicates.remove(group.id)
                                        } else {
                                            model.expandedDuplicates.insert(group.id)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10))
                                    Button("保留一份，其余移入回收站") { model.trashDuplicates(group) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                                if model.expandedDuplicates.contains(group.id) {
                                    ForEach(group.files, id: \.self) { path in
                                        Text(path)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.7)))
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func entryRow(_ entry: DiskEntry) -> some View {
        let fraction = model.totalBytes > 0 ? Double(entry.bytes) / Double(model.totalBytes) : 0
        return HStack(spacing: 10) {
            Image(systemName: entry.isDir ? "folder.fill" : "doc.fill")
                .font(.system(size: 13))
                .foregroundStyle(entry.isDir ? Color.accentColor : Color.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 12, weight: entry.isDir ? .medium : .regular))
                    .lineLimit(1)
                Text(entry.path)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Fmt.bytes(Double(entry.bytes)))
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                Text(String(format: "%.1f%%", fraction * 100))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .frame(width: 90, alignment: .trailing)

            Button { revealInFinder(entry) } label: {
                Image(systemName: "folder")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("在 Finder 中显示")

            if entry.isDir {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { if entry.isDir { model.drill(entry) } }
        .contextMenu {
            Button("在 Finder 中显示") { revealInFinder(entry) }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(entry.isDir ? 1 : 0.55))
        )
        .overlay(alignment: .bottomLeading) {
            GeometryReader { geo in
                Rectangle()
                    .fill(entry.isDir ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.25))
                    .frame(width: max(1, geo.size.width * fraction), height: 2)
            }
            .frame(height: 2)
            .padding(.horizontal, 12)
            .padding(.bottom, 1)
        }
    }

    private func revealInFinder(_ entry: DiskEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)])
    }
}

extension DiskViewModel {
    /// 自测：fixture 覆盖稀疏文件/硬链接/符号链接，断言只按实际占用统计。
    static func fixtureSelfTestJSON() -> String {
        let fm = FileManager.default
        let root = "/tmp/otter-disk-fixture"
        try? fm.removeItem(atPath: root)
        try? fm.createDirectory(atPath: root, withIntermediateDirectories: true)
        fm.createFile(atPath: root + "/real.bin", contents: Data(count: 1_000_000))
        try? fm.linkItem(atPath: root + "/real.bin", toPath: root + "/hardlink.bin")
        // 2GB 稀疏文件：逻辑 2GB，实际约 0
        fm.createFile(atPath: root + "/sparse.bin", contents: Data())
        let fh = FileHandle(forWritingAtPath: root + "/sparse.bin")
        fh?.truncateFile(atOffset: 2_000_000_000)
        fh?.closeFile()
        // 指向 /System 的符号链接，不应被跟随
        try? fm.createSymbolicLink(atPath: root + "/syslink", withDestinationPath: "/System")
        let result = walk(url: URL(fileURLWithPath: root), limit: 1_000_000, isCancelled: { false }, onProgress: { _, _ in })
        let real = (try? fm.attributesOfItem(atPath: root + "/real.bin")[.size] as? Int64) ?? 0
        return "{\"mode\":\"disk-fixture\",\"bytes\":\(result.totalBytes),\"files\":\(result.totalFiles),\"logicalRealFile\":\(real),\"ok\":\(result.totalBytes < 1_500_000 && result.totalFiles == 2)}"
    }

    /// 自测：扫描指定目录并输出总量 + 前 10 项，用于和 du 对照。
    static func selfTestJSON(path: String) -> String {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let result = walk(url: url, limit: 1_000_000, isCancelled: { false }, onProgress: { _, _ in })
        let top = result.entries.prefix(10).map { e in
            "\(e.name):\(e.bytes)"
        }.joined(separator: ",")
        return "{\"mode\":\"disk-scan\",\"path\":\"\(url.path)\",\"bytes\":\(result.totalBytes),\"files\":\(result.totalFiles),\"truncated\":\(result.truncated),\"top\":[\(top)]}"
    }
}