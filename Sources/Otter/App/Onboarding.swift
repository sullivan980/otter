import AppKit
import Combine
import SwiftUI
import UserNotifications

/// 首启引导（独立 NSWindow + SwiftUI，三步：介绍 → 权限 → 自启 + 菜单栏预设）。
/// 只出现一次；跳过、点关闭、完成都会记标记，不依赖主界面任何文件。
final class OnboardingController: NSObject, NSWindowDelegate {
    static let shared = OnboardingController()
    static let completedKey = "otterOnboarded"
    static let installStampKey = "otterInstallStamp"

    static var hasCompleted: Bool { UserDefaults.standard.bool(forKey: completedKey) }
    static func markCompleted() { UserDefaults.standard.set(true, forKey: completedKey) }

    private var window: NSWindow?

    private override init() { super.init() }

    /// 安装指纹：应用包路径 + 创建时间 + 版本。
    /// UserDefaults 在「拖到废纸篓再装回来」后仍会保留，单靠 otterOnboarded 判断不出重装，
    /// 用 .app 的创建时间/路径变化识别新安装，重装后重新走一次引导。
    static func currentInstallStamp() -> String {
        let url = Bundle.main.bundleURL
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let created = (attrs?[.creationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return "\(url.path)|\(Int(created))|\(version)"
    }

    /// AppDelegate 启动时调用；已完成或带 OTTER_NO_ONBOARD=1 时静默跳过
    func showIfNeeded() {
        let stamp = Self.currentInstallStamp()
        let saved = UserDefaults.standard.string(forKey: Self.installStampKey)
        if saved != stamp {
            UserDefaults.standard.set(stamp, forKey: Self.installStampKey)
            UserDefaults.standard.set(false, forKey: Self.completedKey)
        }
        guard !Self.hasCompleted else { return }
        guard ProcessInfo.processInfo.environment["OTTER_NO_ONBOARD"] == nil else { return }
        // 稍等菜单栏初始化完成再弹，避免抢主线程
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.show(force: false)
        }
    }

    /// 右键菜单「欢迎引导」可重看
    func show(force: Bool) {
        guard force || !Self.hasCompleted else { return }
        if let win = window {
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            return
        }

        let model = OnboardingModel()
        let root = OnboardingView(
            model: model,
            onSkip: { [weak self] in self?.finish() },
            onFinish: { [weak self] in
                model.applySelections()
                self?.finish()
            }
        )

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 480),
                           styleMask: [.titled, .closable, .fullSizeContentView],
                           backing: .buffered,
                           defer: false)
        win.title = "欢迎使用 Otter"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.backgroundColor = NSColor.windowBackgroundColor
        win.contentView = NSHostingView(rootView: root)
        win.delegate = self
        win.center()
        window = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    /// 跳过 / 完成 / 点关闭：都记为已引导，之后不再自动出现
    private func finish() {
        Self.markCompleted()
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        Self.markCompleted()
        window = nil
    }
}

// MARK: - 引导模型（偏好 / 权限状态 / 步骤）

final class OnboardingModel: ObservableObject {
    static let stepCount = 3

    @Published var step = 0
    /// D12：首启默认勾选「登录时自动启动」（用户可取消）
    @Published var launchAtLogin: Bool = true
    @Published var preset: MenuBarPreset = MenuBarPreset.current()
    @Published var singleMetric: MetricKind = MetricKind.parse(Prefs.shared.singleMetric) ?? .cpu
    @Published var fullDiskAccess: Bool = OnboardingModel.checkFullDiskAccess()
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var loginItemMessage: String?

    private var observer: NSObjectProtocol?

    init() {
        // 从系统设置切回来时自动刷新权限状态
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPermissions()
        }
        refreshPermissions()
    }

    deinit {
        if let observer = observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: 权限检测

    /// 全磁盘访问：能读到 TCC.db 就视为已授权（读不到就是没授权）
    static func checkFullDiskAccess() -> Bool {
        let paths = [
            NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db",
            "/Library/Application Support/com.apple.TCC/TCC.db",
        ]
        for path in paths {
            if let handle = FileHandle(forReadingAtPath: path) {
                handle.closeFile()
                return true
            }
        }
        return false
    }

    func refreshPermissions() {
        fullDiskAccess = Self.checkFullDiskAccess()
        Notifications.shared.authorizationStatus { [weak self] status in
            self?.notificationStatus = status
        }
    }

    func openPrivacySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    func openNotificationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.Notifications",
            "x-apple.systempreferences:com.apple.preference.notifications",
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    func requestNotifications() {
        Notifications.shared.requestAuthorization { [weak self] _ in
            self?.refreshPermissions()
        }
    }

    /// 通知按钮：只在「未请求」时弹系统授权；已拒绝/已授权都去系统设置（被拒后系统不会再弹窗）
    func handleNotificationPermission() {
        if notificationStatus == .notDetermined {
            requestNotifications()
        } else {
            openNotificationSettings()
        }
    }

    // MARK: 步骤导航

    func next() {
        if step < Self.stepCount - 1 { step += 1 }
    }

    func back() {
        if step > 0 { step -= 1 }
    }

    // MARK: 完成时落盘

    func applySelections() {
        Prefs.shared.menuBarPreset = preset.rawValue
        Prefs.shared.singleMetric = singleMetric.rawValue
        Prefs.shared.launchAtLogin = launchAtLogin

        if launchAtLogin {
            let ok = LoginItem.setEnabled(true)
            if !ok {
                // D12：失败必须可见（不吞）：引导关闭后弹提示，设置页也可看到状态
                loginItemMessage = LoginItem.detailText ?? "登录自启开启失败，可在设置里重试"
                DispatchQueue.main.async { LoginItem.presentFailureAlertIfNeeded() }
            } else {
                loginItemMessage = LoginItem.detailText
            }
        } else {
            LoginItem.setEnabled(false)
            loginItemMessage = nil
        }

        Notifications.shared.requestAuthorization()
        NotificationCenter.default.post(name: ShellPrefs.changedNotification, object: nil)
    }
}

// MARK: - 引导界面

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    var onSkip: () -> Void
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 30)
                .padding(.top, 30)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 30)
                .padding(.top, 16)
            footer
        }
        .frame(width: 620, height: 480)
        .background(background)
    }

    // MARK: 背景 / 顶栏 / 底栏

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(colors: [Color.accentColor.opacity(0.16), Color.clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.6)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "water.waves")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Otter").font(.system(size: 14, weight: .semibold))
                Text("设置向导").font(.system(size: 10.5)).foregroundStyle(.secondary)
            }

            Spacer()

            Text("第 \(model.step + 1) / \(OnboardingModel.stepCount) 步")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case 0: introStep
        case 1: permissionStep
        default: finalStep
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<OnboardingModel.stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i == model.step ? Color.accentColor : Color.primary.opacity(0.15))
                        .frame(width: i == model.step ? 18 : 6, height: 6)
                }
            }
            Spacer()
            Button("跳过") { onSkip() }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if model.step > 0 {
                secondaryButton("上一步") { model.back() }
            }
            if model.step < OnboardingModel.stepCount - 1 {
                primaryButton("继续") { model.next() }
            } else {
                primaryButton("完成") { onFinish() }
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 12)
        .padding(.bottom, 22)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .frame(minWidth: 68)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5))
                .frame(minWidth: 60)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.07)))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 第 1 步：介绍

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("抬眼看得到，低头两下清干净")
                .font(.system(size: 23, weight: .semibold))
                .tracking(-0.3)
            Text("Otter 常驻菜单栏、不占 Dock。点一下獭图标，面板就在菜单栏下方展开。")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            introPreview

            VStack(alignment: .leading, spacing: 9) {
                introBullet(icon: "menubar.rectangle",
                            title: "菜单栏 5 指标",
                            detail: "CPU / 内存 / 磁盘 / 上传 / 下载，默认单色，越界才变色")
                introBullet(icon: "rectangle.on.rectangle",
                            title: "HUD 面板",
                            detail: "5 指标 + TOP3 进程 + 清理 / 卸载快捷入口")
                introBullet(icon: "sparkles",
                            title: "主界面四分区",
                            detail: "清理 / 卸载 / 磁盘 / 设置，重活都在这里")
            }
            Spacer(minLength: 0)
        }
    }

    private var introPreview: some View {
        HStack(spacing: 10) {
            miniMetric("CPU", "42%", fraction: 0.42, tint: Color(nsColor: .systemBlue))
            miniMetric("内存", "61%", fraction: 0.61, tint: Color(nsColor: .systemPurple))
            miniMetric("磁盘", "78%", fraction: 0.78, tint: Color(nsColor: .systemTeal))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
    }

    private func miniMetric(_ title: String, _ value: String, fraction: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 9.5)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()
            HUDBar(fraction: fraction, tint: tint, height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
    }

    private func introBullet(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 第 2 步：权限

    private var permissionGranted: Bool {
        switch model.notificationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    private var notificationStatusText: String {
        switch model.notificationStatus {
        case .authorized, .provisional, .ephemeral: return "已授权"
        case .denied: return "已拒绝"
        case .notDetermined: return "未请求"
        @unknown default: return "未知"
        }
    }

    private var permissionStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("给 Otter 两个权限")
                .font(.system(size: 23, weight: .semibold))
                .tracking(-0.3)
            Text("都可在系统设置里随时改；先跳过也能用，只是部分功能受限。")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)

            permissionCard(
                icon: "internaldrive",
                title: "全磁盘访问",
                detail: "扫描缓存、卸载残留、磁盘分析需要读取受保护目录。",
                granted: model.fullDiskAccess,
                statusText: model.fullDiskAccess ? "已授权" : "未授权",
                primaryTitle: "打开系统设置",
                primaryAction: { model.openPrivacySettings() },
                secondaryTitle: "重新检测",
                secondaryAction: { model.refreshPermissions() }
            )

            permissionCard(
                icon: "bell.badge",
                title: "系统通知",
                detail: model.notificationStatus == .denied
                    ? "系统拒绝了原生通知（未签名构建常见）；Otter 会自动改用脚本通知，也可去「通知」设置里允许 Otter。"
                    : "清理 / 卸载完成后发系统横幅，不用盯着窗口。",
                granted: permissionGranted,
                statusText: notificationStatusText,
                primaryTitle: model.notificationStatus == .notDetermined ? "请求通知" : "打开通知设置",
                primaryAction: { model.handleNotificationPermission() },
                secondaryTitle: "重新检测",
                secondaryAction: { model.refreshPermissions() }
            )

            Text("提示：在系统设置里勾选 Otter 后返回本窗口，状态会自动刷新。")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
    }

    private func permissionCard(icon: String,
                                title: String,
                                detail: String,
                                granted: Bool,
                                statusText: String,
                                primaryTitle: String,
                                primaryAction: @escaping () -> Void,
                                secondaryTitle: String,
                                secondaryAction: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(granted ? Color(nsColor: .systemGreen) : Color.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(statusText)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(granted ? Color(nsColor: .systemGreen).opacity(0.16) : Color.primary.opacity(0.07)))
                        .foregroundStyle(granted ? Color(nsColor: .systemGreen) : Color.secondary)
                }
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button(primaryTitle, action: primaryAction)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.accentColor.opacity(0.14)))
                        .foregroundStyle(Color.accentColor)
                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 15))
                .foregroundStyle(granted ? Color(nsColor: .systemGreen) : Color.primary.opacity(0.25))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.primary.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
    }

    // MARK: - 第 3 步：自启 + 菜单栏预设

    private var finalStep: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("最后两步")
                .font(.system(size: 23, weight: .semibold))
                .tracking(-0.3)
            Text("以后随时可以在「设置」里修改。")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text("登录时自动启动").font(.system(size: 12.5, weight: .medium))
                    Text("重启后菜单栏仍有 Otter，不用手动打开")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $model.launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.primary.opacity(0.045)))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))

            if let message = model.loginItemMessage {
                Text(message)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(nsColor: .systemOrange))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("菜单栏显示")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      spacing: 9) {
                ForEach(MenuBarPreset.allCases) { preset in
                    presetCard(preset)
                }
            }

            if model.preset == .single {
                singleMetricPicker
            }
            Spacer(minLength: 0)
        }
    }

    private func presetCard(_ preset: MenuBarPreset) -> some View {
        let selected = model.preset == preset
        return Button {
            model.preset = preset
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(preset.title).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(preset.preview)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(preset.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(selected ? 0.09 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selected ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.07),
                              lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private var singleMetricPicker: some View {
        HStack(spacing: 6) {
            Text("趋势指标")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Spacer()
            ForEach(MetricKind.allCases) { kind in
                Button {
                    model.singleMetric = kind
                } label: {
                    Text(kind.title)
                        .font(.system(size: 10.5, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(model.singleMetric == kind
                                                   ? Color.accentColor
                                                   : Color.primary.opacity(0.06)))
                        .foregroundStyle(model.singleMetric == kind ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
