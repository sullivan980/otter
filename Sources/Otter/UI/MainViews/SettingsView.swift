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
        MetricDef(id: "mem", name: L("内存","Memory"), icon: "memorychip"),
        MetricDef(id: "disk", name: L("磁盘","Disk"), icon: "internaldrive"),
        MetricDef(id: "up", name: L("上传","Up"), icon: "arrow.up"),
        MetricDef(id: "down", name: L("下载","Down"), icon: "arrow.down")
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
    @Published var installingUpdate = false
    @Published var confirmInstall = false
    @Published var alertsEnabled = Prefs.shared.alertsEnabled
    @Published var alertCPU = Prefs.shared.alertCPU
    @Published var alertMem = Prefs.shared.alertMem
    @Published var alertDisk = Prefs.shared.alertDisk
    @Published var alertDuration = Prefs.shared.alertDuration
    @Published var language = Prefs.shared.language
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
            SectionHeader(title: L("设置", "Settings"),
                          subtitle: L("菜单栏显示、登录自启、通知、系统权限与 HUD 插件。修改即时生效并持久化。",
                                      "Menu bar, login, notifications, permissions and HUD plugins. Changes apply immediately."))
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
                SubHeader(text: L("主题", "Theme"), trailing: L("默认 水波玻璃", "Default: Water Glass"))

                ForEach(themeStore.themes) { item in
                    themeRow(item)
                }

                Divider().opacity(0.5)
                HStack(spacing: 10) {
                    Button(L("打开主题目录","Open Themes Folder")) {
                        if let dir = try? themeStore.ensureThemesDirectory() {
                            NSWorkspace.shared.open(dir)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button(L("重新加载","Reload")) {
                        themeStore.reload()
                        ui.toast = L("已重新加载主题（用户目录同名 id 会覆盖内置）","Themes reloaded (user themes override built-ins)")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                    Text(L("放 \(themeStore.themes.count - AppTheme.builtins.count) 个自定义主题 · 改完点重新加载","\(themeStore.themes.count - AppTheme.builtins.count) custom themes · reload after editing"))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }


    private func themeName(_ item: AppTheme) -> String {
        switch item.id {
        case "A": return L("河岸晨雾", "River Morning")
        case "B": return L("温泉汤屋", "Onsen")
        case "C": return L("深潜", "Deep Dive")
        case "D": return L("纸水獭", "Paper Otter")
        case "E": return L("水波玻璃", "Water Glass")
        default: return item.name
        }
    }

    private func themeTagline(_ item: AppTheme) -> String {
        switch item.id {
        case "A": return L("淡水青蓝 · 安静干净", "Fresh teal, calm and clean")
        case "B": return L("米白陶土 · 蒸汽柔光", "Warm clay, soft steam")
        case "C": return L("深海炭色 · 夜间低刺激", "Deep ocean tones, easy at night")
        case "D": return L("米纸墨线 · 手账感", "Ink on paper")
        case "E": return L("液态玻璃 · 最系统原生", "Liquid glass, native")
        default: return item.tagline
        }
    }

    private func themeRow(_ item: AppTheme) -> some View {
        Button {
            themeStore.theme = item
        } label: {
            HStack(spacing: 12) {
                themeBadge(item)
                VStack(alignment: .leading, spacing: 2) {
                    Text(themeName(item)).font(.system(size: 12, weight: .medium))
                    Text(item.tagline.isEmpty ? L("自定义主题","Custom Theme") : themeTagline(item))
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
                SubHeader(text: L("通用", "General"))

                settingRow(title: L("语言", "Language"),
                           desc: L("切换后需要重启 Otter 生效。", "Restart Otter to apply.")) {
                    Picker("", selection: $ui.language) {
                        Text(L("跟随系统", "System")).tag("system")
                        Text(L("中文","中文")).tag("zh")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                    .onChange(of: ui.language) { value in
                        Prefs.shared.language = value
                        ui.toast = L("语言已保存，重启 Otter 后生效。", "Language saved. Restart Otter to apply.")
                    }
                }

                Divider()

                settingRow(title: L("登录时自动启动","Launch at login"),
                           desc: L("开机后常驻菜单栏，指标随系统启动。","Stay in the menu bar after login.")) {
                    Toggle("", isOn: launchBinding)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                if ui.launchAtLogin != ui.loginActual {
                    HStack(spacing: 6) {
                        Text(ui.launchAtLogin
                             ? L("系统尚未记录该登录项（开发构建未签名时常见）。打包签名后会正常生效。","The system has not recorded this login item (common for unsigned dev builds).")
                             : L("系统仍显示登录项已开启，可能需稍等生效。","The system still shows the login item enabled; it may take a moment."))
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Button(L("重新检测","Recheck")) {
                            refreshLoginActual()
                            if ui.launchAtLogin == ui.loginActual {
                                ui.toast = L("登录项状态已同步。","Login item status synced.")
                            }
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 10))
                    }
                }

                Divider()

                settingRow(title: L("系统通知","Notifications"),
                           desc: notificationDescription) {
                    HStack(spacing: 8) {
                        Text(notificationStatusLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ui.notificationStatus == .denied ? Color.orange : Color.secondary)
                        if ui.notificationStatus == .denied {
                            Button(L("打开通知设置","Open Notification Settings")) {
                                Notifications.shared.openSystemSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Button(L("发送测试","Send Test")) {
                            if ui.notificationStatus == .denied {
                                ui.toast = L("系统拒绝了原生通知：已用脚本通知投递；也可在「通知」设置里允许 Otter。","Native notifications denied; delivered via script. You can allow Otter in Notifications settings.")
                            } else {
                                ui.toast = L("已发送测试通知（若没看到横幅，请检查系统通知设置）。","Test notification sent (check system notification settings if not visible).")
                            }
                            Notifications.shared.post(title: L("Otter 通知测试","Otter Notification Test"),
                                                      body: L("通知已开启，清理与卸载完成后会在这里提醒你。","Notifications are on; cleaning and uninstall results will appear here."))
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

                settingRow(title: L("欢迎引导","Welcome Guide"),
                           desc: L("三步了解菜单栏、系统权限与自启设置，可随时重看。","Menu bar, permissions and login item in three steps.")) {
                    Button(L("重看引导","Show Guide")) {
                        OnboardingController.shared.show(force: true)
                        ui.toast = L("已请求打开欢迎引导。","Welcome guide requested.")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let toast = ui.toast {
                    StatusBanner(kind: .info, title: toast, actionTitle: L("知道了","OK")) { ui.toast = nil }
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
        case .authorized, .provisional, .ephemeral: return L("已允许","Allowed")
        case .denied: return L("已拒绝","Denied")
        default: return L("未请求","Not requested")
        }
    }

    private var notificationDescription: String {
        switch ui.notificationStatus {
        case .denied:
            return L("系统拒绝了原生通知（未签名构建常见）：Otter 会自动用脚本方式投递，仍能收到横幅；点「打开通知设置」可尝试允许 Otter。","Native notifications denied (common for unsigned builds). Otter falls back to script notifications.")
        case .authorized, .provisional, .ephemeral:
            return L("清理或卸载完成后发送通知。","Notify after cleaning or uninstalling.")
        default:
            return L("清理或卸载完成后发送通知（需系统授权）。","Notify after cleaning or uninstalling (requires permission).")
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
                SubHeader(text: L("菜单栏显示", "Menu Bar"))
                Text(L("只保留自定义：勾选指标、调整顺序、选择样式。上传 / 下载默认不勾选，需要时打开即可；獭图标默认不显示。","Custom only: pick metrics, reorder, choose style. Up/Down are off by default; otter icon hidden."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Toggle(L("显示獭图标","Show otter icon"), isOn: $menu.showIcon)
                        .toggleStyle(.switch)
                        .font(.system(size: 11.5))
                    Spacer()
                    Text(L("默认不显示，只留数字","Hidden by default; numbers only"))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }

                menuBarPreview

                Divider()

                HStack(spacing: 10) {
                    Text(L("显示样式","Style")).font(.system(size: 11, weight: .medium))
                    Spacer()
                    Button(L("打开样式目录","Open Styles Folder")) {
                        if let dir = try? menuBarStyles.ensureStylesDirectory() {
                            NSWorkspace.shared.open(dir)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button(L("重新加载","Reload")) {
                        menuBarStyles.reload()
                        ui.toast = L("已重新加载菜单栏样式","Menu bar styles reloaded")
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
                    Toggle(L("按负载着色（≥60% 黄 / ≥85% 红）","Color by load (≥60% yellow / ≥85% red)"), isOn: $menu.colorByLoad)
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
                    Text(L("自定义","Custom")).font(.system(size: 8.5)).foregroundStyle(.tertiary)
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
            Text(L("预览","Preview")).font(.system(size: 10)).foregroundStyle(.tertiary)
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
            Text(L("实时刷新","Live refresh")).font(.system(size: 9)).foregroundStyle(.tertiary)
        }
    }

    // MARK: Otter 回收站

    private var trashSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                SubHeader(text: L("Otter 回收站", "Otter Trash"), trailing: "\(ui.trashCount) \(L("项", "items")) · \(Fmt.bytes(Double(ui.trashBytes)))")
                Text(L("清理的项目先移到这里（可恢复）；清空后才真正释放磁盘。系统缓存需要管理员，不进回收站。","Cleaned items move here first (restorable); disk space is freed after emptying. System caches require admin and do not enter Trash."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button(L("恢复全部","Restore All")) {
                        let result = SafeTrashService.shared.restore(all: true)
                        ui.toast = L("已恢复 \(result.restored) 项","Restored \(result.restored) items") + (result.errors.isEmpty ? "" : "，\(result.errors.count) 项失败")
                        refreshTrash()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(ui.trashCount == 0)

                    Button(L("清空回收站","Empty Trash")) { ui.confirmEmptyTrash = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(ui.trashCount == 0)

                    Spacer()
                    Button(L("刷新","Refresh")) { refreshTrash() }
                        .buttonStyle(.borderless)
                        .font(.system(size: 10))
                }
            }
        }
        .alert(L("清空 Otter 回收站？","Empty Otter Trash?"), isPresented: $ui.confirmEmptyTrash) {
            Button(L("取消","Cancel"), role: .cancel) {}
            Button(L("清空","Empty"), role: .destructive) {
                let result = SafeTrashService.shared.empty()
                ui.toast = L("已清空 \(result.removed) 项，释放 \(Fmt.bytes(Double(result.bytes)))","Emptied \(result.removed) items, freed \(Fmt.bytes(Double(result.bytes)))")
                refreshTrash()
            }
        } message: {
            Text(L("将永久删除 \(ui.trashCount) 项，无法恢复。","Permanently delete \(ui.trashCount) items. This cannot be undone."))
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
                SubHeader(text: L("清理规则插件", "Clean Rule Plugins"), trailing: "\(cleanRules.rules.count)")
                Text(L("自定义清理分类：JSON 放 ~/Library/Application Support/Otter/cleanrules/，路径必须在主目录下；扫描后作为额外分类出现，白名单依然生效。","Custom clean categories: JSON in ~/Library/Application Support/Otter/cleanrules/. Paths must be under your home folder; whitelist still applies."))
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
                    Button(L("打开规则目录","Open Rules Folder")) {
                        if let dir = try? cleanRules.ensureRulesDirectory() { NSWorkspace.shared.open(dir) }
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    Button(L("重新加载","Reload")) {
                        cleanRules.reload()
                        ui.toast = L("已重新加载清理规则","Clean rules reloaded")
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
                SubHeader(text: L("提醒", "Reminders"))
                HStack {
                    Toggle(L("低磁盘提醒","Low disk reminder"), isOn: $ui.lowDiskReminder)
                        .toggleStyle(.switch)
                        .font(.system(size: 11.5))
                        .onChange(of: ui.lowDiskReminder) { value in Prefs.shared.lowDiskReminderEnabled = value }
                    Spacer()
                    Text(L("超过告警阈值时每天最多提醒一次","At most one reminder per day above the alert threshold")).font(.system(size: 9.5)).foregroundStyle(.tertiary)
                }
                HStack {
                    Text(L("定期清理提醒","Cleanup reminder")).font(.system(size: 11.5))
                    Spacer()
                    Picker("", selection: $ui.cleanReminderDays) {
                        Text(L("关闭","Off")).tag(0)
                        Text(L("7 天","7 days")).tag(7)
                        Text(L("14 天","14 days")).tag(14)
                        Text(L("30 天","30 days")).tag(30)
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
                SubHeader(text: L("阈值告警", "Threshold Alerts"), trailing: L("默认关闭", "Off by default"))
                Text(L("指标连续超过阈值的时间达到设定值后发一次系统通知；冷却期内不重复。","Notify once when a metric stays above its threshold; no repeats during cooldown."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Toggle(L("启用告警","Enable alerts"), isOn: $ui.alertsEnabled)
                        .toggleStyle(.switch)
                        .font(.system(size: 11.5))
                        .onChange(of: ui.alertsEnabled) { value in Prefs.shared.alertsEnabled = value }
                    Spacer()
                    Picker(L("持续","Sustained"), selection: $ui.alertDuration) {
                        Text(L("10 秒","10s")).tag(10.0)
                        Text(L("30 秒","30s")).tag(30.0)
                        Text(L("60 秒","60s")).tag(60.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                    .onChange(of: ui.alertDuration) { value in Prefs.shared.alertDuration = value }
                }

                thresholdRow("CPU", value: $ui.alertCPU, key: "cpu")
                thresholdRow(L("内存","Memory"), value: $ui.alertMem, key: "mem")
                thresholdRow(L("磁盘","Disk"), value: $ui.alertDisk, key: "disk")
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
                SubHeader(text: L("诊断与日志", "Diagnostics"), trailing: L("不上传任何数据", "No data uploaded"))
                Text(L("导出内容：版本、系统/硬件、实时指标、偏好、插件加载错误、最近 100 行操作日志、Otter 崩溃报告列表。","Includes version, hardware, metrics, preferences, plugin errors, last 100 log lines and Otter crash reports."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button(L("保存诊断报告","Save Diagnostics")) {
                        if let url = DiagnosticsService.export(metrics: state.metrics, state: state) {
                            ui.toast = L("已保存：\(url.path)","Saved: \(url.path)")
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } else {
                            ui.toast = L("保存失败","Save failed")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button(L("复制诊断文本","Copy Diagnostics")) {
                        let text = DiagnosticsService.text(metrics: state.metrics, state: state)
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(text, forType: .string)
                        ui.toast = L("诊断文本已复制","Diagnostics copied")
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
                SubHeader(text: L("更新", "Updates"), trailing: "\(L("当前", "Current")) v\(appVersion)")
                Text(L("填 GitHub Releases API 或自定义 JSON 地址（https）。可自动下载并替换安装，重启 Otter。","GitHub Releases API or custom JSON (https). Can download and install automatically, then restart Otter."))
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
                    Button(ui.checkingUpdate ? L("检查中…","Checking…") : L("检查更新","Check for Updates")) { checkUpdate() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(ui.checkingUpdate || ui.updateFeed.isEmpty)
                }

                if let status = ui.updateStatus {
                    Text(status)
                        .font(.system(size: 10.5))
                        .foregroundStyle(status.hasPrefix(L("发现","Found")) ? Color.accentColor : Color.secondary)
                }

                if let info = ui.updateInfo {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("发现新版本 v\(info.version)","Version v\(info.version) available"))
                            .font(.system(size: 11.5, weight: .medium))
                        if !info.notes.isEmpty {
                            Text(info.notes)
                                .font(.system(size: 9.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        HStack(spacing: 8) {
                            if info.dmgURL != nil {
                                Button(ui.installingUpdate ? L("安装中…","Installing…") : L("下载并安装","Download & Install")) {
                                    ui.confirmInstall = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(ui.installingUpdate || ui.downloadingUpdate)
                                Button(ui.downloadingUpdate ? L("下载中…","Downloading…") : L("仅下载 DMG","Download DMG Only")) { downloadUpdate(info) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(ui.downloadingUpdate || ui.installingUpdate)
                            }
                            if let page = info.pageURL {
                                Button(L("打开发布页","Open Release Page")) { NSWorkspace.shared.open(page) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
        .alert(L("下载并安装 v\(ui.updateInfo?.version ?? "")？","Download and install v\(ui.updateInfo?.version ?? "")?") , isPresented: $ui.confirmInstall) {
            Button(L("取消","Cancel"), role: .cancel) {}
            Button(L("下载并安装","Download & Install"), role: .destructive) {
                if let info = ui.updateInfo { downloadAndInstall(info) }
            }
        } message: {
            Text(L("将下载 DMG、校验版本并替换 /Applications/Otter.app，完成后 Otter 会退出并重启。","Downloads the DMG, verifies the version, replaces /Applications/Otter.app, then Otter quits and relaunches."))
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
                ui.updateStatus = L("已是最新版本（v\(current)）","Up to date (v\(current))")
            case .available(let info):
                ui.updateInfo = info
                ui.updateStatus = L("发现新版本 v\(info.version)","Version v\(info.version) available")
            case .failure(let message):
                ui.updateStatus = message
            }
        }
    }

    private func downloadAndInstall(_ info: UpdateInfo) {
        guard let url = info.dmgURL else { return }
        ui.installingUpdate = true
        ui.updateStatus = L("正在下载更新…", "Downloading update…")
        UpdateService.download(url) { result in
            switch result {
            case .success(let file):
                ui.updateStatus = L("正在校验并安装…", "Verifying and installing…")
                UpdateInstaller.installDownloaded(dmgURL: file, expectedVersion: info.version) { installResult in
                    DispatchQueue.main.async {
                        ui.installingUpdate = false
                        switch installResult {
                        case .success:
                            ui.updateStatus = L("安装完成，正在重启…", "Installed. Restarting…")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { NSApp.terminate(nil) }
                        case .failure(let error):
                            ui.updateStatus = L("安装失败：", "Install failed: ") + error.localizedDescription
                        }
                    }
                }
            case .failure(let error):
                ui.installingUpdate = false
                ui.updateStatus = L("下载失败：", "Download failed: ") + error.localizedDescription
            }
        }
    }

    private func downloadUpdate(_ info: UpdateInfo) {
        guard let url = info.dmgURL else { return }
        ui.downloadingUpdate = true
        ui.updateStatus = L("正在下载…","Downloading…")
        UpdateService.download(url) { result in
            ui.downloadingUpdate = false
            switch result {
            case .success(let file):
                ui.updateStatus = L("已下载到 \(file.path)，打开后拖入 Applications 覆盖安装。","Downloaded to \(file.path). Drag into Applications to update.")
                NSWorkspace.shared.open(file)
            case .failure(let error):
                ui.updateStatus = L("下载失败：\(error.localizedDescription)","Download failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: 清理保护（白名单）

    private var whitelistSection: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                SubHeader(text: L("清理保护", "Clean Protection"), trailing: "\(whitelist.paths.count)")
                Text(L("这些路径不会被安装包 / 项目产物清理删除；适合放正在开发的项目或重要目录。","These paths are never deleted by installer/artifact cleaning."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if whitelist.paths.isEmpty {
                    Text(L("暂无保护路径","No protected paths")).font(.system(size: 10.5)).foregroundStyle(.tertiary)
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
                            Button(L("移除","Remove")) { whitelist.remove(path) }
                                .buttonStyle(.borderless)
                                .font(.system(size: 10))
                        }
                        .padding(.vertical, 2)
                    }
                }

                HStack(spacing: 8) {
                    Button(L("添加路径…","Add Path…")) {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = true
                        panel.prompt = L("保护","Protected")
                        panel.message = L("选择要保护的文件或目录","Choose files or folders to protect")
                        if panel.runModal() == .OK {
                            for url in panel.urls { whitelist.add(url.path) }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button(L("打开配置文件","Open Config File")) {
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
                    Text(L("原生 macOS 系统状态与清理工具 · 原生清理引擎","Native macOS system monitor and cleaner"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Text(L("原生引擎","Native engine")).font(.system(size: 9.5)).foregroundStyle(.tertiary)
                        Text(L("菜单栏常驻 · HUD 400×520","Menu bar · HUD 400×520")).font(.system(size: 9.5)).foregroundStyle(.tertiary)
                        Text(L("内存 footprint 目标 ≤25MB","Memory footprint target ≤25MB")).font(.system(size: 9.5)).foregroundStyle(.tertiary)
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