import SwiftUI

final class MaintenanceViewModel: ObservableObject {
    @Published private(set) var report = MaintenanceReport()
    @Published private(set) var isRefreshing = false
    @Published var errorText: String?
    @Published var dnsRunning = false
    @Published var dnsMessage: String?
    @Published var confirmDNS = false

    func flushDNS() {
        dnsRunning = true
        dnsMessage = nil
        MaintenanceService.flushDNS { [weak self] result in
            guard let self = self else { return }
            self.dnsRunning = false
            switch result {
            case .success: self.dnsMessage = "DNS 缓存已刷新"
            case .failure(let error): self.dnsMessage = "刷新失败：\(error.localizedDescription)"
            }
        }
    }

    func refresh() {
        isRefreshing = true
        errorText = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let r = MaintenanceService.collect()
            DispatchQueue.main.async {
                self?.report = r
                self?.isRefreshing = false
            }
        }
    }
}

struct MaintenanceView: View {
    @ObservedObject var model: MaintenanceViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "维护",
                          subtitle: "系统状态只读诊断；维护任务仅提供预览说明，不会执行 DNS / Spotlight 等有风险操作。") {
                Button(model.isRefreshing ? "检测中…" : "重新检测") { model.refresh() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRefreshing)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        infoCard("系统", icon: "desktopcomputer", rows: [
                            ("macOS", model.report.osVersion),
                            ("架构", model.report.arch),
                            ("机型", model.report.model),
                            ("已运行", Fmt.uptime(model.report.uptime)),
                        ])
                        diskCard
                    }
                    HStack(alignment: .top, spacing: 12) {
                        infoCard("Spotlight", icon: "magnifyingglass", rows: [
                            ("索引状态", model.report.spotlight),
                        ])
                        infoCard("本地快照", icon: "clock.arrow.circlepath", rows: [
                            ("快照数量", "\(model.report.snapshotCount)"),
                        ])
                        infoCard("启动项", icon: "power", rows: [
                            ("用户 LaunchAgents", "\(model.report.userAgents)"),
                            ("系统 LaunchAgents", "\(model.report.systemAgents)"),
                            ("系统 LaunchDaemons", "\(model.report.systemDaemons)"),
                        ])
                    }
                    tasksPreview
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .onAppear { if model.report.osVersion.isEmpty { model.refresh() } }
        .alert("刷新 DNS 缓存？", isPresented: $model.confirmDNS) {
            Button("取消", role: .cancel) {}
            Button("刷新", role: .destructive) { model.flushDNS() }
        } message: {
            Text("会请求一次管理员授权，并短暂影响域名解析；不会删除任何文件。")
        }
    }

    private var diskCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle("磁盘健康", icon: "internaldrive")
                row("卷", model.report.volumeName.isEmpty ? "—" : model.report.volumeName)
                row("类型", model.report.isSSD.map { $0 ? "SSD" : "机械硬盘" } ?? "—")
                row("SMART", model.report.smartStatus ?? "—")
                row("可用", "\(Fmt.bytes(Double(model.report.freeBytes))) / \(Fmt.bytes(Double(model.report.totalBytes)))")
            }
        }
    }

    private func infoCard(_ title: String, icon: String, rows: [(String, String)]) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle(title, icon: icon)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, pair in
                    row(pair.0, pair.1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardTitle(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.secondary)
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(name).font(.system(size: 10.5)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
        }
    }

    private var tasksPreview: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver").font(.system(size: 11))
                    Text("维护任务（仅预览）").font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("当前版本不执行").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)

                dnsTaskRow
                taskRow("重建 Spotlight 索引", "高耗时、占 CPU；会影响搜索直到完成", "high")
                taskRow("重建字体缓存", "需要重启；可能与正在运行的应用冲突", "high")
                taskRow("运行系统定期维护脚本", "需要管理员授权；建议空闲时执行", "admin")

                if let message = model.dnsMessage {
                    Text(message)
                        .font(.system(size: 9.5))
                        .foregroundStyle(message.hasPrefix("刷新失败") ? Color.orange : Color.secondary)
                }

                Text("DNS 刷新为低风险受控动作；Spotlight / 字体缓存等仍只做说明。")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var dnsTaskRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("刷新 DNS 缓存").font(.system(size: 10.5, weight: .medium))
                Text("需要管理员授权；会短暂影响域名解析").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer()
            if model.dnsRunning {
                ProgressView().controlSize(.small)
            } else {
                Button("执行…") { model.confirmDNS = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func taskRow(_ title: String, _ detail: String, _ kind: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: kind == "admin" ? "lock.shield" : "exclamationmark.triangle")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 10.5, weight: .medium))
                Text(detail).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(kind == "admin" ? "需管理员" : "高风险")
                .font(.system(size: 8.5))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
                .foregroundStyle(.secondary)
        }
    }
}