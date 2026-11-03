import SwiftUI
import AppKit

final class StartupViewModel: ObservableObject {
    @Published private(set) var items: [LaunchItem] = []
    @Published var query: String = ""
    @Published private(set) var isScanning = false
    @Published private(set) var errorText: String?
    @Published private(set) var resultMessage: String?

    func scan() {
        isScanning = true
        errorText = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let list = LaunchItemService.scan()
            DispatchQueue.main.async {
                self?.items = list
                self?.isScanning = false
            }
        }
    }

    var filtered: [LaunchItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return q.isEmpty ? items : items.filter {
            $0.label.lowercased().contains(q) || $0.program.lowercased().contains(q) || $0.path.lowercased().contains(q)
        }
    }

    var grouped: [(LaunchScope, [LaunchItem])] {
        let scopes: [LaunchScope] = [.userAgent, .systemAgent, .systemDaemon]
        return scopes.compactMap { scope in
            let list = filtered.filter { $0.scope == scope }
            return list.isEmpty ? nil : (scope, list)
        }
    }

    func setDisabled(_ item: LaunchItem, _ disabled: Bool) {
        switch LaunchItemService.setDisabled(item, disabled: disabled) {
        case .success:
            resultMessage = disabled ? "已禁用 \(item.label)" : "已启用 \(item.label)"
            OtterLog.shared.add(resultMessage ?? "")
            scan()
        case .failure(let error):
            errorText = error.localizedDescription
        }
    }
}

struct StartupView: View {
    @ObservedObject var model: StartupViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: L("启动项", "Startup"),
                          subtitle: L("查看 LaunchAgents / LaunchDaemons；用户项可直接禁用（会同步 launchctl），系统项需管理员，当前只读。",
                                      "Inspect LaunchAgents / LaunchDaemons. User items can be disabled (syncs launchctl); system items require admin and are read-only.")) {
                Button(model.isScanning ? "扫描中…" : "刷新") { model.scan() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isScanning)
            }

            VStack(alignment: .leading, spacing: 10) {
                SearchField(placeholder: "搜索 label / 程序路径…", text: Binding(
                    get: { model.query }, set: { model.query = $0 }))
                if let error = model.errorText {
                    StatusBanner(kind: .warning, title: error)
                }
                if let message = model.resultMessage {
                    StatusBanner(kind: .success, title: message)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(model.grouped, id: \.0) { pair in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(pair.0.title).font(.system(size: 11, weight: .semibold))
                                    Text("\(pair.1.count)").font(.system(size: 9)).foregroundStyle(.secondary)
                                }
                                ForEach(pair.1) { item in
                                    itemRow(item)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear { if model.items.isEmpty { model.scan() } }
    }

    private func itemRow(_ item: LaunchItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.scope == .userAgent ? "person.crop.circle" : "gearshape.2")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.label).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                    if item.disabled {
                        Text("已禁用").font(.system(size: 8.5)).padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                            .foregroundStyle(.orange)
                    }
                    if item.runAtLoad {
                        Text("RunAtLoad").font(.system(size: 8.5)).foregroundStyle(.tertiary)
                    }
                    if item.keepAlive {
                        Text("KeepAlive").font(.system(size: 8.5)).foregroundStyle(.tertiary)
                    }
                }
                Text(item.program)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)]) }
                .buttonStyle(.plain)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
            if item.scope.requiresAdmin {
                Text("需管理员").font(.system(size: 9)).foregroundStyle(.tertiary)
                    .help("系统启动项当前只读")
            } else {
                Button(item.disabled ? "启用" : "禁用") {
                    model.setDisabled(item, !item.disabled)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.6)))
    }
}