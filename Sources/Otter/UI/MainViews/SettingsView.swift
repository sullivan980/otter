import SwiftUI
import AppKit
import Foundation
import UserNotifications

// MARK: - 菜单栏设置状态
//
// 4 预设：极简 / CPU+内存 / 单指标 / 自定义。
// 自定义：5 指标勾选 + 顺序（Prefs.menuBarOrder）+ 按负载着色。
// 修改后写 Prefs 并发 "OtterMenuBarPrefsChanged"，dev-shell 的菜单栏 1 秒内刷新。
final class MenuBarSettings: ObservableObject {
    static let didChangeNotification = Notification.Name("OtterMenuBarPrefsChanged")

    struct MetricDef {
        let id: String
        let name: String
        let icon: String
    }

    static let defs: [MetricDef] = [
        MetricDef(id: "cpu", name: "CPU", icon: "cpu"),
        MetricDef(id: "mem", name: "内存", icon: "memorychip"),
        MetricDef(id: "disk", name: "磁盘", icon: "internaldrive"),
        MetricDef(id: "up", name: "上传", icon: "arrow.up"),
        MetricDef(id: "down", name: "下载", icon: "arrow.down")
    ]

    @Published var preset: String { didSet { persist() } }
    @Published var singleMetric: String { didSet { persist() } }
    @Published var showCPU: Bool { didSet { persist() } }
    @Published var showMem: Bool { didSet { persist() } }
    @Published var showDisk: Bool { didSet { persist() } }
    @Published var showUp: Bool { didSet { persist() } }
    @Published var showDown: Bool { didSet { persist() } }
    @Published var colorByLoad: Bool { didSet { persist() } }
    @Published var order: [String] { didSet { persist() } }
    @Published var showIcon: Bool { didSet { persist() } }

    init() {
        let p = Prefs.shared
        preset = "custom"
        singleMetric = p.singleMetric
        showCPU = p.showCPU
        showMem = p.showMem
        showDisk = p.showDisk
        showUp = p.showUp
        showDown = p.showDown
        colorByLoad = p.colorByLoad
        order = p.menuBarOrder
        showIcon = p.menuBarShowIcon
        if p.menuBarPreset != "custom" { p.menuBarPreset = "custom" }
    }

    /// 外部（其他窗口）改动后回读。
    func refresh() {
        let p = Prefs.shared
        if preset != p.menuBarPreset { preset = p.menuBarPreset }
        if singleMetric != p.singleMetric { singleMetric = p.singleMetric }
        if showCPU != p.showCPU { showCPU = p.showCPU }
        if showMem != p.showMem { showMem = p.showMem }
        if showDisk != p.showDisk { showDisk = p.showDisk }
        if showUp != p.showUp { showUp = p.showUp }
        if showDown != p.showDown { showDown = p.showDown }
        if colorByLoad != p.colorByLoad { colorByLoad = p.colorByLoad }
        if order != p.menuBarOrder { order = p.menuBarOrder }
        if showIcon != p.menuBarShowIcon { showIcon = p.menuBarShowIcon }
        if preset != "custom" { preset = "custom" }
    }

    private func persist() {
        let p = Prefs.shared
        p.menuBarPreset = preset
        p.singleMetric = singleMetric
        p.showCPU = showCPU
        p.showMem = showMem
        p.showDisk = showDisk
        p.showUp = showUp
        p.showDown = showDown
        p.colorByLoad = colorByLoad
        p.menuBarOrder = order
        p.menuBarShowIcon = showIcon
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    // MARK: 查询

    func metricName(_ id: String) -> String {
        Self.defs.first { $0.id == id }?.name ?? id
    }

    func metricIcon(_ id: String) -> String {
        Self.defs.first { $0.id == id }?.icon ?? "circle"
    }

    func isVisible(_ id: String) -> Bool {
        switch id {
        case "cpu": return showCPU
        case "mem": return showMem
        case "disk": return showDisk
        case "up": return showUp
        case "down": return showDown
        default: return false
        }
    }

    func setVisible(_ id: String, _ visible: Bool) {
        switch id {
        case "cpu": showCPU = visible
        case "mem": showMem = visible
        case "disk": showDisk = visible
        case "up": showUp = visible
        case "down": showDown = visible
        default: break
        }
    }

    func move(_ id: String, up: Bool) {
        guard let index = order.firstIndex(of: id) else { return }
        let target = up ? index - 1 : index + 1
        guard target >= 0, target < order.count else { return }
        var next = order
        next.swapAt(index, target)
        order = next
    }

    /// 菜单栏预览（与真实菜单栏模块顺序/口径一致）。
    func previewItems(metrics: SystemMetrics) -> [(id: String, icon: String, value: String)] {
        let ids = order.filter { isVisible($0) }
        return ids.map { id in
            switch id {
            case "mem": return ("mem", "memorychip", Fmt.percent(metrics.memUsedPercent))
            case "disk": return ("disk", "internaldrive", Fmt.percent(metrics.diskUsedPercent))
            case "up": return ("up", "arrow.up", Fmt.rate(metrics.upBytesPerSec))
            case "down": return ("down", "arrow.down", Fmt.rate(metrics.downBytesPerSec))
            default: return ("cpu", "cpu", Fmt.percent(metrics.cpuPercent))
            }
        }
    }
}

// MARK: - 设置分区（视图）
// 局部 UI 状态放 ObservableObject（本机无 SwiftUIMacros，不能用 @State）。
final class SettingsUIState: ObservableObject {
    @Published var launchAtLogin: Bool = Prefs.shared.launchAtLogin
    @Published var loginActual: Bool = LoginItem.isEnabled
    @Published var notificationsEnabled: Bool = Prefs.shared.notificationsEnabled
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var toast: String?
    @Published var updateFeed: String = Prefs.shared.updateFeedURL
    @Published var updateStatus: String?
    @Published var updateInfo: UpdateInfo?
    @Published var checkingUpdate = false
    @Published var downloadingUpdate = false
    @Published var alertsEnabled = Prefs.shared.alertsEnabled
    @Published var alertCPU = Prefs.shared.alertCPU
    @Published var alertMem = Prefs.shared.alertMem
    @Published var alertDisk = Prefs.shared.alertDisk
    @Published var alertDuration = Prefs.shared.alertDuration
    @Published var lowDiskReminder = Prefs.shared.lowDiskReminderEnabled
    @Published var cleanReminderDays = Prefs.shared.cleanReminderDays
    @Published var trashCount = 0
    @Published var trashBytes: Int64 = 0
    @Published var trashBatches = 0
    @Published var confirmEmptyTrash = false
}

struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var themeStore = ThemeStore.shared

    private var theme: AppTheme { themeStore.theme }
    @StateObject private var menu = MenuBarSettings()
    @StateObject private var permissions = PermissionModel()
    @StateObject private var ui = SettingsUIState()
    @ObservedObject private var plugins = PluginStore.shared
    @ObservedObject private var menuBarStyles = MenuBarStyleStore.shared
    @ObservedObject private var whitelist = WhitelistStore.shared
    @ObservedObject private var cleanRules = CleanRuleStore.shared

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "设置",
                          subtitle: "菜单栏显示、登录自启、通知、系统权限与 HUD 插件。修改即时生效并持久化。")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    themeSection
                    generalSection
                    menuBarSection
                    trashSection
                    whitelistSection
                    cleanRulesSection
                    updateSection
                    remindersSection
                    alertsSection
                    diagnosticsSection
                    PermissionSection(model: permissions)
                    PluginSection(store: plugins)
                    aboutSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            menu.refresh()
            permissions.autoCheckIfNeeded()
            refreshLoginActual()
            ui.notificationsEnabled = Prefs.shared.notificationsEnabled
            refreshNotificationStatus()
            refreshTrash()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshNotificationStatus()
        }
    }

    // MARK: 主题

    private var themeSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                SubHeader(text: "主题", trailing: "默认 水波玻璃")

                ForEach(themeStore.themes) { item in
                    themeRow(item)
                }

                Divider().opacity(0.5)
                HStack(spacing: 10) {
                    Button("打开主题目录") {
                        if let dir = try? themeStore.ensureThemesDirectory() {
                            NSWorkspace.shared.open(dir)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("重新加载") {
                        themeStore.reload()
                        ui.toast = "已重新加载主题（用户目录同名 id 会覆盖内置）"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                    Text("放 \(themeStore.themes.count - AppTheme.builtins.count) 个自定义主题 · 改完点重新加载")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }


    private func themeRow(_ item: AppTheme) -> some View {
        Button {
            themeStore.theme = item
        } label: {
            HStack(spacing: 12) {
                themeBadge(item)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.system(size: 12, weight: .medium))
                    Text(item.tagline.isEmpty ? "自定义主题" : item.tagline)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                themeSwatches(item)
                if item == theme {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func themeBadge(_ item: AppTheme) -> some View {
        Text(item.id)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: item.id == "D" ? 4 : 7, style: .continuous)
                    .fill(item == theme ? theme.accent : Color.primary.opacity(0.07))
            )
            .foregroundStyle(item == theme ? (theme.isDark ? Color.black : Color.white) : Color.secondary)
    }

    private func themeSwatches(_ item: AppTheme) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(item.swatches.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
            }
        }
    }

    // MARK: 通用

    private var generalSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                SubHeader(text: "通用")

                settingRow(title: "登录时自动启动",
                           desc: "开机后常驻菜单栏，指标随系统启动。") {
                    Toggle("", isOn: launchBinding)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                if ui.launchAtLogin != ui.loginActual {
                    HStack(spacing: 6) {
                        Text(ui.launchAtLogin
                             ? "系统尚未记录该登录项（开发构建未签名时常见）。打包签名后会正常生效。"
                             : "系统仍显示登录项已开启，可能需稍等生效。")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Button("重新检测") {
                            refreshLoginActual()
                            if ui.launchAtLogin == ui.loginActual {
                                ui.toast = "登录项状态已同步。"
                            }
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 10))
                    }
                }

                Divider()

                settingRow(title: "系统通知",
                           desc: notificationDescription) {
                    HStack(spacing: 8) {
                        Text(notificationStatusLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ui.notificationStatus == .denied ? Color.orange : Color.secondary)
                        if ui.notificationStatus == .denied {
                            Button("打开通知设置") {
                                Notifications.shared.openSystemSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Button("发送测试") {
                            if ui.notificationStatus == .denied {
                                ui.toast = "系统拒绝了原生通知：已用脚本通知投递；也可在「通知」设置里允许 Otter。"
                            } else {
                                ui.toast = "已发送测试通知（若没看到横幅，请检查系统通知设置）。"
                            }
                            Notifications.shared.post(title: "Otter 通知测试",
                                                      body: "通知已开启，清理与卸载完成后会在这里提醒你。")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!ui.notificationsEnabled)
                        Toggle("", isOn: notificationBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }

                Divider()

                settingRow(title: "欢迎引导",
                           desc: "三步了解菜单栏、系统权限与自启设置，可随时重看。") {
                    Button("重看引导") {
                        OnboardingController.shared.show(force: true)
                        ui.toast = "已请求打开欢迎引导。"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let toast = ui.toast {
                    StatusBanner(kind: .info, title: toast, actionTitle: "知道了") { ui.toast = nil }
                }
            }
        }
    }

    private var launchBinding: Binding<Bool> {
        Binding(get: { ui.launchAtLogin }, set: { value in
            ui.launchAtLogin = value
            Prefs.shared.launchAtLogin = value
            // 兼容 dev-shell 的 @discardableResult 版本：Void / Bool 返回值都可忽略。
            LoginItem.setEnabled(value)
            // 立即回读一次，再轮询几次：SMAppService 的状态更新有延迟，
            // 避免开关已关闭却残留「登录项尚未移除」的陈旧提示。
            refreshLoginActual()
            for delay in [0.2, 0.6, 1.2, 2.4] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    refreshLoginActual()
                }
            }
        })
    }

    /// 按系统实际状态刷新登录项，并清除已一致的陈旧提示。
    private func refreshLoginActual() {
        let actual = LoginItem.isEnabled
        if ui.loginActual != actual { ui.loginActual = actual }
        if ui.launchAtLogin == actual { ui.toast = nil }
    }

    private var notificationStatusLabel: String {
        switch ui.notificationStatus {
        case .authorized, .provisional, .ephemeral: return "已允许"
        case .denied: return "已拒绝"
        default: return "未请求"
        }
    }

    private var notificationDescription: String {
        switch ui.notificationStatus {
        case .denied:
            return "系统拒绝了原生通知（未签名构建常见）：Otter 会自动用脚本方式投递，仍能收到横幅；点「打开通知设置」可尝试允许 Otter。"
        case .authorized, .provisional, .ephemeral:
            return "清理或卸载完成后发送通知。"
        default:
            return "清理或卸载完成后发送通知（需系统授权）。"
        }
    }

    private func refreshNotificationStatus() {
        Notifications.shared.authorizationStatus { status in
            if ui.notificationStatus != status { ui.notificationStatus = status }
            if status == .denied { ui.notificationsEnabled = false }
        }
    }

    private var notificationBinding: Binding<Bool> {
        Binding(get: { ui.notificationsEnabled }, set: { value in
            ui.notificationsEnabled = value
            Prefs.shared.notificationsEnabled = value
            if value { Notifications.shared.requestAuthorization() }
        })
    }

    // MARK: 菜单栏

    private var menuBarSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                SubHeader(text: "菜单栏显示")
                Text("只保留自定义：勾选指标、调整顺序、选择样式。上传 / 下载默认不勾选，需要时打开即可；獭图标默认不显示。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Toggle("显示獭图标", isOn: $menu.showIcon)
                        .toggleStyle(.switch)
                        .font(.system(size: 11.5))
                    Spacer()
                    Text("默认不显示，只留数字")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }

                menuBarPreview

                Divider()

                HStack(spacing: 10) {
                    Text("显示样式").font(.system(size: 11, weight: .medium))
                    Spacer()
                    Button("打开样式目录") {
                        if let dir = try? menuBarStyles.ensureStylesDirectory() {
                            NSWorkspace.shared.open(dir)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("重新加载") {
                        menuBarStyles.reload()
                        ui.toast = "已重新加载菜单栏样式"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                VStack(spacing: 2) {
                    ForEach(menuBarStyles.styles) { style in
                        menuBarStyleRow(style)
                    }
                }

                if !menuBarStyles.loadErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(menuBarStyles.loadErrors.enumerated()), id: \.offset) { _, line in
                            Text("• \(line)").font(.system(size: 9.5)).foregroundStyle(.orange)
                        }
                    }
                }

                Divider()

                VStack(spacing: 6) {
                    ForEach(Array(menu.order.enumerated()), id: \.offset) { index, id in
                        HStack(spacing: 8) {
                            Toggle("", isOn: Binding(
                                get: { menu.isVisible(id) },
                                set: { menu.setVisible(id, $0) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            Image(systemName: menu.metricIcon(id))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .frame(width: 15)
                            Text(menu.metricName(id)).font(.system(size: 11.5))
                            Spacer()
                            Button {
                                menu.move(id, up: true)
                            } label: {
                                Image(systemName: "chevron.up").font(.system(size: 9, weight: .bold))
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)
                            Button {
                                menu.move(id, up: false)
                            } label: {
                                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == menu.order.count - 1)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Divider()
                HStack {
                    Toggle("按负载着色（≥60% 黄 / ≥85% 红）", isOn: $menu.colorByLoad)
                        .toggleStyle(.switch)
                        .font(.system(size: 11.5))
                    Spacer()
                }
            }
        }
    }

    private func menuBarStyleRow(_ style: MenuBarStyle) -> some View {
        let selected = menuBarStyles.style.id == style.id
        return Button {
            menuBarStyles.select(style.id)
        } label: {
            HStack(spacing: 8) {
                Text(style.name).font(.system(size: 11.5, weight: selected ? .medium : .regular))
                Spacer()
                Text(menuBarStyleSample(style))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                if !style.isBuiltin {
                    Text("自定义").font(.system(size: 8.5)).foregroundStyle(.tertiary)
                }
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func menuBarStyleSample(_ style: MenuBarStyle) -> String {
        let items = menu.previewItems(metrics: state.metrics)
        let parts = items.map { item -> String in
            var s = ""
            if style.showLabels { s += menu.metricName(item.id) + " " }
            s += item.value
            return s
        }
        return parts.isEmpty ? "Otter" : parts.joined(separator: style.separator)
    }

    private var menuBarPreview: some View {
        let items = menu.previewItems(metrics: state.metrics)
        let style = menuBarStyles.style
        return HStack(spacing: 8) {
            Text("预览").font(.system(size: 10)).foregroundStyle(.tertiary)
            HStack(spacing: 0) {
                if menu.showIcon {
                    Image(systemName: "water.waves")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 6)
                }
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Text(style.separator)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 3) {
                        if style.showIcons {
                            Image(systemName: item.icon)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        if style.showLabels {
                            Text(menu.metricName(item.id))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Text(item.value)
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
            Spacer()
            Text("实时刷新").font(.system(size: 9)).foregroundStyle(.tertiary)
        }
    }

    // MARK: Otter 回收站

    private var trashSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                SubHeader(text: "Otter 回收站", trailing: "\(ui.trashCount) 项 · \(Fmt.bytes(Double(ui.trashBytes)))")
                Text("清理的项目先移到这里（可恢复）；清空后才真正释放磁盘。系统缓存需要管理员，不进回收站。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button("恢复全部") {
                        let result = SafeTrashService.shared.restore(all: true)
                        ui.toast = "已恢复 \(result.restored) 项" + (result.errors.isEmpty ? "" : "，\(result.errors.count) 项失败")
                        refreshTrash()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(ui.trashCount == 0)

                    Button("清空回收站") { ui.confirmEmptyTrash = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(ui.trashCount == 0)

                    Spacer()
                    Button("刷新") { refreshTrash() }
                        .buttonStyle(.borderless)
                        .font(.system(size: 10))
                }
            }
        }
        .alert("清空 Otter 回收站？", isPresented: $ui.confirmEmptyTrash) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                let result = SafeTrashService.shared.empty()
                ui.toast = "已清空 \(result.removed) 项，释放 \(Fmt.bytes(Double(result.bytes)))"
                refreshTrash()
            }
        } message: {
            Text("将永久删除 \(ui.trashCount) 项，无法恢复。")
        }
    }

    private func refreshTrash() {
        let batches = SafeTrashService.shared.list()
        ui.trashBatches = batches.count
        ui.trashCount = batches.reduce(0) { $0 + $1.count }
        ui.trashBytes = batches.reduce(0) { $0 + $1.bytes }
    }

    // MARK: 清理规则插件

    private var cleanRulesSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                SubHeader(text: "清理规则插件", trailing: "\(cleanRules.rules.count) 条")
                Text("自定义清理分类：JSON 放 ~/Library/Application Support/Otter/cleanrules/，路径必须在主目录下；扫描后作为额外分类出现，白名单依然生效。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(cleanRules.rules) { rule in
                    HStack(spacing: 8) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(rule.name).font(.system(size: 11))
                        Spacer()
                        Text(rule.roots.map { $0.path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }.joined(separator: "、"))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if !cleanRules.loadErrors.isEmpty {
                    ForEach(Array(cleanRules.loadErrors.enumerated()), id: \.offset) { _, line in
                        Text("• \(line)").font(.system(size: 9.5)).foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 8) {
                    Button("打开规则目录") {
                        if let dir = try? cleanRules.ensureRulesDirectory() { NSWorkspace.shared.open(dir) }
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    Button("重新加载") {
                        cleanRules.reload()
                        ui.toast = "已重新加载清理规则"
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    Spacer()
                }
            }
        }
    }

    // MARK: 提醒

    private var remindersSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                SubHeader(text: "提醒")
                HStack {
                    Toggle("低磁盘提醒", isOn: $ui.lowDiskReminder)
                        .toggleStyle(.switch)
                        .font(.system(size: 11.5))
                        .onChange(of: ui.lowDiskReminder) { value in Prefs.shared.lowDiskReminderEnabled = value }
                    Spacer()
                    Text("超过告警阈值时每天最多提醒一次").font(.system(size: 9.5)).foregroundStyle(.tertiary)
                }
                HStack {
                    Text("定期清理提醒").font(.system(size: 11.5))
                    Spacer()
                    Picker("", selection: $ui.cleanReminderDays) {
                        Text("关闭").tag(0)
                        Text("7 天").tag(7)
                        Text("14 天").tag(14)
                        Text("30 天").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                    .onChange(of: ui.cleanReminderDays) { value in Prefs.shared.cleanReminderDays = value }
                }
            }
        }
    }

    // MARK: 告警

    private var alertsSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                SubHeader(text: "阈值告警", trailing: "默认关闭")
                Text("指标连续超过阈值的时间达到设定值后发一次系统通知；冷却期内不重复。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Toggle("启用告警", isOn: $ui.alertsEnabled)
                        .toggleStyle(.switch)
                        .font(.system(size: 11.5))
                        .onChange(of: ui.alertsEnabled) { value in Prefs.shared.alertsEnabled = value }
                    Spacer()
                    Picker("持续", selection: $ui.alertDuration) {
                        Text("10 秒").tag(10.0)
                        Text("30 秒").tag(30.0)
                        Text("60 秒").tag(60.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                    .onChange(of: ui.alertDuration) { value in Prefs.shared.alertDuration = value }
                }

                thresholdRow("CPU", value: $ui.alertCPU, key: "cpu")
                thresholdRow("内存", value: $ui.alertMem, key: "mem")
                thresholdRow("磁盘", value: $ui.alertDisk, key: "disk")
            }
        }
    }

    private func thresholdRow(_ name: String, value: Binding<Double>, key: String) -> some View {
        HStack(spacing: 10) {
            Text(name).font(.system(size: 11)).frame(width: 36, alignment: .leading)
            Slider(value: Binding(
                get: { value.wrappedValue },
                set: { newValue in
                    value.wrappedValue = newValue
                    switch key {
                    case "cpu": Prefs.shared.alertCPU = newValue
                    case "mem": Prefs.shared.alertMem = newValue
                    default: Prefs.shared.alertDisk = newValue
                    }
                }
            ), in: 50...100, step: 5)
            Text("\(Int(value.wrappedValue))%")
                .font(.system(size: 10.5, design: .monospaced))
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: 诊断

    private var diagnosticsSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                SubHeader(text: "诊断与日志", trailing: "不上传任何数据")
                Text("导出内容：版本、系统/硬件、实时指标、偏好、插件加载错误、最近 100 行操作日志、Otter 崩溃报告列表。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button("保存诊断报告") {
                        if let url = DiagnosticsService.export(metrics: state.metrics, state: state) {
                            ui.toast = "已保存：\(url.path)"
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } else {
                            ui.toast = "保存失败"
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("复制诊断文本") {
                        let text = DiagnosticsService.text(metrics: state.metrics, state: state)
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(text, forType: .string)
                        ui.toast = "诊断文本已复制"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
            }
        }
    }

    // MARK: 更新

    private var updateSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                SubHeader(text: "更新", trailing: "当前 v\(appVersion)")
                Text("填 GitHub Releases API 或自定义 JSON 地址（https）。只检查与下载 DMG，不自动安装。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    TextField("https://api.github.com/repos/OWNER/REPO/releases/latest",
                              text: Binding(
                                get: { ui.updateFeed },
                                set: { ui.updateFeed = $0; Prefs.shared.updateFeedURL = $0 }
                              ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 10.5, design: .monospaced))
                    Button(ui.checkingUpdate ? "检查中…" : "检查更新") { checkUpdate() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(ui.checkingUpdate || ui.updateFeed.isEmpty)
                }

                if let status = ui.updateStatus {
                    Text(status)
                        .font(.system(size: 10.5))
                        .foregroundStyle(status.hasPrefix("发现") ? Color.accentColor : Color.secondary)
                }

                if let info = ui.updateInfo {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("发现新版本 v\(info.version)")
                            .font(.system(size: 11.5, weight: .medium))
                        if !info.notes.isEmpty {
                            Text(info.notes)
                                .font(.system(size: 9.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        HStack(spacing: 8) {
                            if info.dmgURL != nil {
                                Button(ui.downloadingUpdate ? "下载中…" : "下载 DMG") { downloadUpdate(info) }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(ui.downloadingUpdate)
                            }
                            if let page = info.pageURL {
                                Button("打开发布页") { NSWorkspace.shared.open(page) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
    }

    private func checkUpdate() {
        ui.checkingUpdate = true
        ui.updateStatus = nil
        ui.updateInfo = nil
        UpdateService.check(feedURLString: ui.updateFeed) { result in
            ui.checkingUpdate = false
            switch result {
            case .upToDate(let current):
                ui.updateStatus = "已是最新版本（v\(current)）"
            case .available(let info):
                ui.updateInfo = info
                ui.updateStatus = "发现新版本 v\(info.version)"
            case .failure(let message):
                ui.updateStatus = message
            }
        }
    }

    private func downloadUpdate(_ info: UpdateInfo) {
        guard let url = info.dmgURL else { return }
        ui.downloadingUpdate = true
        ui.updateStatus = "正在下载…"
        UpdateService.download(url) { result in
            ui.downloadingUpdate = false
            switch result {
            case .success(let file):
                ui.updateStatus = "已下载到 \(file.path)，打开后拖入 Applications 覆盖安装。"
                NSWorkspace.shared.open(file)
            case .failure(let error):
                ui.updateStatus = "下载失败：\(error.localizedDescription)"
            }
        }
    }

    // MARK: 清理保护（白名单）

    private var whitelistSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                SubHeader(text: "清理保护", trailing: "\(whitelist.paths.count) 条")
                Text("这些路径不会被安装包 / 项目产物清理删除；适合放正在开发的项目或重要目录。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if whitelist.paths.isEmpty {
                    Text("暂无保护路径").font(.system(size: 10.5)).foregroundStyle(.tertiary)
                } else {
                    ForEach(whitelist.paths, id: \.self) { path in
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(path)
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("移除") { whitelist.remove(path) }
                                .buttonStyle(.borderless)
                                .font(.system(size: 10))
                        }
                        .padding(.vertical, 2)
                    }
                }

                HStack(spacing: 8) {
                    Button("添加路径…") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = true
                        panel.prompt = "保护"
                        panel.message = "选择要保护的文件或目录"
                        if panel.runModal() == .OK {
                            for url in panel.urls { whitelist.add(url.path) }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("打开配置文件") {
                        try? FileManager.default.createDirectory(at: whitelist.fileURL.deletingLastPathComponent(),
                                                                 withIntermediateDirectories: true)
                        if !FileManager.default.fileExists(atPath: whitelist.fileURL.path) {
                            try? Data("[]".utf8).write(to: whitelist.fileURL)
                        }
                        NSWorkspace.shared.open(whitelist.fileURL)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
            }
        }
    }

    // MARK: 关于

    private var aboutSection: some View {
        PanelCard {
            HStack(alignment: .center, spacing: 13) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text("Otter").font(.system(size: 16, weight: .bold))
                        KindTag(text: "v" + appVersion, color: .secondary)
                    }
                    Text("原生 macOS 系统状态与清理工具 · 原生清理引擎")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Text("原生引擎").font(.system(size: 9.5)).foregroundStyle(.tertiary)
                        Text("菜单栏常驻 · HUD 400×520").font(.system(size: 9.5)).foregroundStyle(.tertiary)
                        Text("内存 footprint 目标 ≤25MB").font(.system(size: 9.5)).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }

    // MARK: 通用行

    private func settingRow<Accessory: View>(title: String,
                                             desc: String,
                                             @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(desc).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 10)
            accessory()
        }
    }
}