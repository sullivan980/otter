import SwiftUI
import AppKit

// MARK: - 空间：安装包 / 项目构建产物（原生扫描，不依赖 mole）

final class SpaceViewModel: ObservableObject {
    @Published var mode: SpaceScanMode = .installers
    @Published private(set) var installers: [InstallerItem] = []
    @Published private(set) var artifacts: [ArtifactItem] = []
    @Published var selected: Set<String> = []
    @Published private(set) var isScanning = false
    @Published private(set) var progress = ""
    @Published var errorText: String?
    @Published var resultText: String?
    @Published var confirmDelete = false

    private var generation = 0

    var itemsCount: Int { mode == .installers ? installers.count : artifacts.count }
    var selectedBytes: Int64 {
        if mode == .installers {
            return installers.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.bytes }
        }
        return artifacts.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.bytes }
    }
    var totalBytes: Int64 {
        mode == .installers
            ? installers.reduce(0) { $0 + $1.bytes }
            : artifacts.reduce(0) { $0 + $1.bytes }
    }
    var selectedCount: Int { selected.count }

    func autoScanIfRequested() {
        guard ProcessInfo.processInfo.environment["OTTER_AUTO_SCAN"] == "space" else { return }
        if ProcessInfo.processInfo.environment["OTTER_SPACE_MODE"] == "projects" {
            mode = .projects
        }
        scan()
    }

    func scan() {
        generation += 1
        let gen = generation
        isScanning = true
        selected = []
        errorText = nil
        resultText = nil
        progress = "准备扫描…"
        installers = []
        artifacts = []
        let mode = mode
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let installers = mode == .installers ? SpaceScanner.scanInstallers() : []
            let artifacts = mode == .projects ? SpaceScanner.scanProjects() : []
            DispatchQueue.main.async {
                guard self.generation == gen else { return }
                self.isScanning = false
                self.installers = installers
                self.artifacts = artifacts
                self.progress = "扫描完成"
                if mode == .installers {
                    self.selected = Set(installers.map { $0.id })
                }
            }
        }
    }

    func selectAll() {
        if mode == .installers { selected = Set(installers.map { $0.id }) }
        else { selected = Set(artifacts.map { $0.id }) }
    }

    func clearSelection() { selected.removeAll() }

    func deleteSelected() {
        let paths: [String]
        if mode == .installers { paths = installers.filter { selected.contains($0.id) }.map { $0.path } }
        else { paths = artifacts.filter { selected.contains($0.id) }.map { $0.path } }
        let result = SpaceScanner.delete(paths: paths)
        if result.errors.isEmpty {
            resultText = "已删除 \(result.removed) 项，释放 \(Fmt.bytes(Double(result.bytes)))"
            OperationResultCenter.shared.post(kind: .success, title: "空间清理完成",
                                              message: "已删除 \(result.removed) 项，释放 \(Fmt.bytes(Double(result.bytes)))")
        } else {
            resultText = "已删除 \(result.removed) 项，\(result.errors.count) 项失败"
            errorText = result.errors.joined(separator: "\n")
            OperationResultCenter.shared.post(kind: .warning, title: "部分项目未删除",
                                              message: "成功 \(result.removed) 项，失败 \(result.errors.count) 项")
        }
        scan()
    }
}

struct SpaceView: View {
    @ObservedObject var model: SpaceViewModel
    @ObservedObject private var whitelist = WhitelistStore.shared

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: L("空间", "Space"),
                          subtitle: L("安装包与项目构建产物清理；只读扫描，删除前二次确认，白名单路径自动跳过。",
                                      "Clean installers and project build artifacts. Read-only scan, confirmation before delete, whitelist paths skipped.")) {
                HStack(spacing: 8) {
                    Picker("", selection: $model.mode) {
                        ForEach(SpaceScanMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 190)
                    .onChange(of: model.mode) { _ in model.scan() }
                    Button(model.isScanning ? "扫描中…" : "扫描") { model.scan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isScanning)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(model.mode.subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)

                if let error = model.errorText {
                    StatusBanner(kind: .error, title: "部分操作失败", message: error)
                }
                if let result = model.resultText {
                    StatusBanner(kind: .success, title: result)
                }

                if model.isScanning {
                    PanelCard {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(model.progress).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                } else if model.itemsCount == 0 {
                    EmptyStateView(icon: model.mode.systemImage,
                                   title: model.mode == .installers ? "没有找到安装包" : "没有找到可清理的构建产物",
                                   message: model.mode == .installers
                                        ? "扫描了下载目录、邮件下载和 Telegram 下载，未发现 .dmg/.pkg/.iso/.xip。"
                                        : "扫描了 ~/Code、~/Projects、~/Developer、~/Documents，未发现 7 天以上的构建产物。",
                                   actionTitle: "重新扫描") { model.scan() }
                        .frame(minHeight: 260)
                } else {
                    summaryBar
                    listArea
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear { model.autoScanIfRequested() }
        .alert("删除所选项？", isPresented: $model.confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { model.deleteSelected() }
        } message: {
            Text("将直接删除 \(model.selectedCount) 项，共 \(Fmt.bytes(Double(model.selectedBytes)))，不可恢复。白名单路径会自动跳过。")
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 10) {
            Text(model.mode == .installers ? "共 \(model.itemsCount) 个安装包" : "共 \(model.itemsCount) 个构建产物")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("· 总计 \(Fmt.bytes(Double(model.totalBytes)))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Button("全选") { model.selectAll() }
                .buttonStyle(.bordered).controlSize(.small)
            Button("清空") { model.clearSelection() }
                .buttonStyle(.bordered).controlSize(.small)
            Button("删除所选") { model.confirmDelete = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.selectedCount == 0)
        }
    }

    private var listArea: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if model.mode == .installers {
                    ForEach(model.installers) { item in
                        row(id: item.id, title: item.name, subtitle: item.path,
                            meta: item.bytes == 0 ? "云端/不占空间" : Fmt.bytes(Double(item.bytes)),
                            date: item.modified)
                    }
                } else {
                    ForEach(model.artifacts) { item in
                        row(id: item.id, title: "\(item.project) / \(item.name)", subtitle: item.path,
                            meta: Fmt.bytes(Double(item.bytes)), date: item.modified)
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func row(id: String, title: String, subtitle: String, meta: String, date: Date?) -> some View {
        let selected = model.selected.contains(id)
        return Button {
            if selected { model.selected.remove(id) } else { model.selected.insert(id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                    Text(subtitle).font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if let date = date {
                    Text(Self.dateFormatter.string(from: date))
                        .font(.system(size: 9.5)).foregroundStyle(.tertiary)
                }
                Text(meta).font(.system(size: 11, weight: .medium)).monospacedDigit()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(selected ? 0.08 : 0.035)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}