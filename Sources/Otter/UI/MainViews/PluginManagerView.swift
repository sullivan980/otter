import SwiftUI
import AppKit

// MARK: - 插件管理（设置页内嵌）
//
// 安装（选择文件夹/manifest.json）/ 启用 / 删除 / 打开插件目录；非法 manifest 逐条显示错误。
/// 插件管理页的局部 UI 状态（本机无 SwiftUIMacros，不能使用 @State）。
final class PluginUIState: ObservableObject {
    @Published var pendingAlert: PluginPendingAlert?
    @Published var alertMessage: String?
    @Published var alertKind: BannerKind = .success
}

/// 同一时间只挂一个 alert：覆盖安装 / 删除确认。
enum PluginPendingAlert: Identifiable {
    case overwrite(URL)
    case delete(HUDPlugin)

    var id: String {
        switch self {
        case .overwrite(let url): return "overwrite:" + url.path
        case .delete(let plugin): return "delete:" + plugin.id
        }
    }
}

struct PluginSection: View {
    @ObservedObject var store: PluginStore = PluginStore.shared
    @StateObject private var ui = PluginUIState()

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SubHeader(text: "HUD 插件 v1")
                    Spacer()
                    Button {
                        openPluginsDirectory()
                    } label: {
                        Label("打开插件目录", systemImage: "folder")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button {
                        installFromPanel()
                    } label: {
                        Label("安装插件…", systemImage: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Text("插件是声明式 HUD 样式包（manifest.json，无代码执行）。安装后立即启用并在 HUD 生效；内置插件不可删除，用户插件不能与内置插件同 id（会被拒绝）。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let message = ui.alertMessage {
                    StatusBanner(kind: ui.alertKind, title: message,
                                 actionTitle: "知道了") { ui.alertMessage = nil }
                }
                if let error = store.lastActionError {
                    StatusBanner(kind: .error, title: error, actionTitle: "关闭") { store.lastActionError = nil }
                }
                if !store.loadErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("加载告警（\(store.loadErrors.count)）")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.orange)
                        ForEach(Array(store.loadErrors.enumerated()), id: \.offset) { _, line in
                            Text("• \(line)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange.opacity(0.08))
                    )
                }

                if store.plugins.isEmpty {
                    Text("暂无可用的插件。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 18)
                } else {
                    VStack(spacing: 6) {
                        ForEach(store.plugins) { plugin in
                            pluginRow(plugin)
                        }
                    }
                }
            }
        }
        .alert(item: $ui.pendingAlert) { item in
            switch item {
            case .overwrite(let url):
                return Alert(title: Text("插件已存在"),
                             message: Text("已安装同 id 插件。覆盖会替换插件目录中的现有文件，确定继续？"),
                             primaryButton: .destructive(Text("覆盖安装")) {
                                 do {
                                     try store.install(from: url, overwrite: true)
                                     ui.alertKind = .success
                                     ui.alertMessage = "已覆盖安装并启用。"
                                 } catch {
                                     ui.alertKind = .error
                                     ui.alertMessage = error.localizedDescription
                                 }
                             },
                             secondaryButton: .cancel(Text("取消")))
            case .delete(let plugin):
                return Alert(title: Text("删除插件？"),
                             message: Text("将删除「\(plugin.name)」（\(plugin.id)）的插件目录。此操作不可撤销。"),
                             primaryButton: .destructive(Text("删除")) {
                                 store.remove(id: plugin.id)
                                 ui.alertKind = .success
                                 ui.alertMessage = "已删除「\(plugin.name)」。"
                             },
                             secondaryButton: .cancel(Text("取消")))
            }
        }
    }

    private func pluginRow(_ plugin: HUDPlugin) -> some View {
        let active = store.activeId == plugin.id
        let builtin = store.isBuiltin(plugin.id)
        return HStack(alignment: .center, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.06))
                    .frame(width: 32, height: 32)
                Image(systemName: builtin ? "square.grid.2x2" : "puzzlepiece.extension")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(active ? Color.accentColor : Color.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(plugin.name).font(.system(size: 12, weight: .medium))
                    KindTag(text: builtin ? "内置" : "用户", color: builtin ? .blue : .purple)
                    if active { KindTag(text: "已启用", color: .green) }
                }
                Text("\(plugin.id) · v\(plugin.version) · \(Int(plugin.resolvedWidth))×\(Int(plugin.resolvedHeight)) · \(plugin.rows.count) 行")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(plugin.rows.map { "\($0.metric) \($0.style)" }.joined(separator: " · "))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            if !active {
                Button("启用") {
                    store.activeId = plugin.id
                    ui.alertKind = .success
                    ui.alertMessage = "已启用「\(plugin.name)」。HUD 将按该插件渲染。"
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            if !builtin {
                Button("删除") { ui.pendingAlert = .delete(plugin) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(active ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.06),
                              lineWidth: active ? 1.2 : 1)
        )
    }

    // MARK: 动作

    private func installFromPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.message = "选择插件文件夹（包含 manifest.json），或单个 manifest.json 文件"
        panel.prompt = "安装"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.install(from: url)
            ui.alertKind = .success
            ui.alertMessage = "已安装并启用插件。"
        } catch {
            if case PluginError.alreadyInstalled(_) = error {
                ui.pendingAlert = .overwrite(url)
            } else {
                ui.alertKind = .error
                ui.alertMessage = error.localizedDescription
            }
        }
    }

    private func openPluginsDirectory() {
        do {
            let dir = try store.ensurePluginsDirectory()
            NSWorkspace.shared.open(dir)
        } catch {
            ui.alertKind = .error
            ui.alertMessage = error.localizedDescription
        }
    }
}