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
    @ObservedObject private var themeStore = ThemeStore.shared
    @StateObject private var ui = PluginUIState()

    private var accent: Color { themeStore.theme.accent }

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    SubHeader(text: L("HUD 插件", "HUD Plugins"),
                             trailing: "\(store.plugins.count) " + L("个", "items"))
                    Spacer()
                    Button { openPluginsDirectory() } label: {
                        Image(systemName: "folder").font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .help(L("打开插件目录", "Open Plugins Folder"))
                    Button { store.reload() } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .help(L("重新加载", "Reload"))
                    Button { installFromPanel() } label: {
                        Label(L("安装插件…", "Install Plugin…"), systemImage: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Text(L("声明式 HUD 样式包，无代码执行；放入插件目录后自动重载。",
                       "Declarative HUD style packs, no code execution; hot-reload after adding files."))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .help(L("格式：manifest.json；style 支持 cardRadius / spacing / showSparkline / typeface（system/mono/serif/rounded）。",
                            "Format: manifest.json; style supports cardRadius / spacing / showSparkline / typeface (system/mono/serif/rounded)."))

                if let message = ui.alertMessage {
                    StatusBanner(kind: ui.alertKind, title: message,
                                 actionTitle: L("知道了","OK")) { ui.alertMessage = nil }
                }
                if let error = store.lastActionError {
                    StatusBanner(kind: .error, title: error, actionTitle: L("关闭","Off")) { store.lastActionError = nil }
                }
                if !store.loadErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("加载告警（\(store.loadErrors.count)）","Load warnings (\(store.loadErrors.count))"))
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
                    Text(L("暂无可用的插件。","No plugins available."))
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
                return Alert(title: Text(L("插件已存在","Plugin exists")),
                             message: Text(L("已安装同 id 插件。覆盖会替换插件目录中的现有文件，确定继续？","A plugin with this id is installed. Overwrite existing files?")),
                             primaryButton: .destructive(Text(L("覆盖安装","Overwrite"))) {
                                 do {
                                     try store.install(from: url, overwrite: true)
                                     ui.alertKind = .success
                                     ui.alertMessage = L("已覆盖安装并启用。","Overwritten and enabled.")
                                 } catch {
                                     ui.alertKind = .error
                                     ui.alertMessage = error.localizedDescription
                                 }
                             },
                             secondaryButton: .cancel(Text(L("取消","Cancel"))))
            case .delete(let plugin):
                return Alert(title: Text(L("删除插件？","Delete plugin?")),
                             message: Text(L("将删除「\(plugin.name)」（\(plugin.id)）的插件目录。此操作不可撤销。","Delete the plugin folder for \(plugin.name) (\(plugin.id))? This cannot be undone.")),
                             primaryButton: .destructive(Text(L("删除","Delete"))) {
                                 store.remove(id: plugin.id)
                                 ui.alertKind = .success
                                 ui.alertMessage = L("已删除「\(plugin.name)」。","Deleted \(plugin.name).")
                             },
                             secondaryButton: .cancel(Text(L("取消","Cancel"))))
            }
        }
    }

    private func pluginRow(_ plugin: HUDPlugin) -> some View {
        let active = store.activeId == plugin.id
        let builtin = store.isBuiltin(plugin.id)
        return HStack(alignment: .center, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? accent.opacity(0.16) : Color.primary.opacity(0.06))
                    .frame(width: 32, height: 32)
                Image(systemName: builtin ? "square.grid.2x2" : "puzzlepiece.extension")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(active ? accent : Color.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(plugin.name).font(.system(size: 12, weight: .medium))
                    KindTag(text: builtin ? L("内置","Built-in") : L("用户","User"), color: builtin ? accent : .secondary)
                    if active { KindTag(text: L("已启用","Enabled"), color: accent) }
                }
                Text(L("\(plugin.id) · v\(plugin.version) · \(Int(plugin.resolvedWidth))×\(Int(plugin.resolvedHeight)) · \(plugin.rows.count) 行","\(plugin.id) · v\(plugin.version) · \(Int(plugin.resolvedWidth))×\(Int(plugin.resolvedHeight)) · \(plugin.rows.count) rows"))
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
                Button(L("启用","Enable")) {
                    store.activeId = plugin.id
                    ui.alertKind = .success
                    ui.alertMessage = L("已启用「\(plugin.name)」。HUD 将按该插件渲染。","Enabled \(plugin.name). HUD will use this plugin.")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            if !builtin {
                Button(L("删除","Delete")) { ui.pendingAlert = .delete(plugin) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(active ? accent.opacity(0.08) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(active ? accent.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: 动作

    private func installFromPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.message = L("选择插件文件夹（包含 manifest.json），或单个 manifest.json 文件","Choose a plugin folder (with manifest.json) or a manifest.json file")
        panel.prompt = L("安装","Install")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.install(from: url)
            ui.alertKind = .success
            ui.alertMessage = L("已安装并启用插件。","Plugin installed and enabled.")
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