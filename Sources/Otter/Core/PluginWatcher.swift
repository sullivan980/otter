import Foundation

/// 监听用户插件/主题目录：文件变化后自动重载（样式迭代不用重装应用）。
final class PluginWatcher {
    static let shared = PluginWatcher()
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?
    private init() {}

    func start() {
        try? PluginStore.shared.ensurePluginsDirectory()
        try? ThemeStore.shared.ensureThemesDirectory()
        try? MenuBarStyleStore.shared.ensureStylesDirectory()
        try? CleanRuleStore.shared.ensureRulesDirectory()
        watch(PluginStore.shared.pluginsDirectory)
        watch(ThemeStore.shared.themesDirectory)
        watch(MenuBarStyleStore.shared.stylesDirectory)
        watch(CleanRuleStore.shared.rulesDirectory)
    }

    private func watch(_ dir: URL) {
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .main)
        src.setEventHandler { [weak self] in self?.scheduleReload() }
        src.setCancelHandler { close(fd) }
        src.resume()
        sources.append(src)
    }

    private func scheduleReload() {
        pending?.cancel()
        let item = DispatchWorkItem {
            PluginStore.shared.reload()
            ThemeStore.shared.reload()
            MenuBarStyleStore.shared.reload()
            CleanRuleStore.shared.reload()
            NotificationCenter.default.post(name: ShellPrefs.changedNotification, object: nil)
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }
}