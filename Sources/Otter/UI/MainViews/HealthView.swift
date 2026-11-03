import SwiftUI

final class HealthViewModel: ObservableObject {
    @Published private(set) var report: HealthReport?
    @Published private(set) var isScanning = false
    @Published private(set) var progress = ""

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        progress = "准备体检…"
        OtterLog.shared.add("开始系统体检")
        HealthCheckService.scan(progress: { [weak self] line in
            DispatchQueue.main.async { self?.progress = line }
        }, completion: { [weak self] report in
            guard let self = self else { return }
            self.report = report
            self.isScanning = false
            self.progress = ""
            OtterLog.shared.add("体检完成：\(report.score) 分，\(report.issues.count) 项")
        })
    }
}

struct HealthView: View {
    @ObservedObject var model: HealthViewModel
    @ObservedObject private var history = CleanHistoryStore.shared
    var onNavigate: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: L("体检", "Health Check"),
                          subtitle: L("只读扫描，不会删除或修改任何文件；体检完成后按建议去对应分区处理。",
                                      "Read-only scan. Nothing is deleted or changed; follow suggestions to handle issues.")) {
                Button(model.isScanning ? L("体检中…", "Checking…") : L("开始体检", "Start Check")) {
                    model.scan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isScanning)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let report = model.report {
                        scoreCard(report)
                        if report.issues.isEmpty {
                            StatusBanner(kind: .success, title: L("状态良好", "All good"),
                                         message: L("没有发现需要处理的问题。", "Nothing needs attention."))
                        } else {
                            ForEach(report.issues) { issue in
                                issueCard(issue)
                            }
                        }
                        ledgerCard
                    } else if model.isScanning {
                        scanningCard
                    } else {
                        EmptyStateView(icon: "stethoscope",
                                       title: L("给电脑做一次体检", "Run a health check"),
                                       message: L("扫描缓存、废纸篓、大文件、启动项与磁盘状态，给出一份可执行的建议。",
                                                  "Scans caches, Trash, large files, startup items and disk, then gives actionable suggestions."),
                                       actionTitle: L("开始体检", "Start Check")) { model.scan() }
                            .frame(minHeight: 280)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .onAppear { if model.report == nil && !model.isScanning { model.scan() } }
    }

    private var scanningCard: some View {
        PanelCard {
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("正在体检…", "Checking…")).font(.system(size: 11.5, weight: .semibold))
                    Text(model.progress).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func scoreCard(_ report: HealthReport) -> some View {
        PanelCard {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 8)
                    Circle().trim(from: 0, to: CGFloat(report.score) / 100)
                        .stroke(scoreColor(report.score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(report.score)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(L("健康分", "Score")).font(.system(size: 8.5)).foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 5) {
                    Text(report.issues.isEmpty
                         ? L("状态良好", "Looks good")
                         : (report.issues.contains { $0.severity == .critical }
                            ? L("需要处理", "Needs attention")
                            : L("有一些可优化项", "A few things to improve")))
                        .font(.system(size: 16, weight: .semibold))
                    Text(L("可清理 \(Fmt.bytes(Double(report.cleanableBytes))) · 废纸篓 \(Fmt.bytes(Double(report.trashBytes))) · 可用空间 \(String(format: "%.1f", report.diskFreePercent))%",
                           "Cleanable \(Fmt.bytes(Double(report.cleanableBytes))) · Trash \(Fmt.bytes(Double(report.trashBytes))) · Free \(String(format: "%.1f", report.diskFreePercent))%"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Text(L("体检时间：", "Checked: ") + report.checkedAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9.5)).foregroundStyle(.tertiary)
                }
                Spacer()
                Button(L("重新体检", "Recheck")) { model.scan() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func issueCard(_ issue: HealthIssue) -> some View {
        PanelCard {
            HStack(spacing: 12) {
                Image(systemName: icon(issue.severity))
                    .font(.system(size: 16))
                    .foregroundStyle(color(issue.severity))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.title).font(.system(size: 12, weight: .semibold))
                    Text(issue.detail).font(.system(size: 10)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(issue.actionTitle) { onNavigate(issue.section) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var ledgerCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal").font(.system(size: 11))
                    Text(L("空间账本", "Space Ledger")).font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(history.events.count) " + L("次操作", "operations"))
                        .font(.system(size: 9.5)).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 22) {
                    ledgerStat(L("累计释放", "Freed"), Fmt.bytes(Double(history.totalFreed)))
                    ledgerStat(L("移入回收站", "In Trash"), Fmt.bytes(Double(history.totalTrashed)))
                    Spacer()
                    Button(L("清理记录", "Clear History")) { history.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .disabled(history.events.isEmpty)
                }

                ForEach(history.events.prefix(3)) { event in
                    HStack(spacing: 8) {
                        Text(event.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text(L("清理", "Clean"))
                            .font(.system(size: 9.5))
                        Spacer()
                        Text(Fmt.bytes(Double(event.freedBytes + event.trashedBytes)))
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    }
                }
            }
        }
    }

    private func ledgerStat(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.system(size: 9)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return .green }
        if score >= 60 { return .orange }
        return .red
    }

    private func color(_ severity: HealthIssue.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .accentColor
        }
    }

    private func icon(_ severity: HealthIssue.Severity) -> String {
        switch severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}
