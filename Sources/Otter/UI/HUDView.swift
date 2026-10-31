import SwiftUI

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
    }
}

struct HUDView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            cpuTile
            HStack(spacing: 10) {
                tile(title: "内存", value: Fmt.percent(state.metrics.memUsedPercent),
                     sub: memSub, fraction: state.metrics.memUsedPercent / 100, tint: .blue)
                tile(title: "磁盘", value: Fmt.percent(state.metrics.diskUsedPercent),
                     sub: diskSub, fraction: state.metrics.diskUsedPercent / 100, tint: .green)
            }
            netTile
            procs
            actions
        }
        .padding(14)
        .frame(width: 400, height: 520)
        .background(
            VisualEffectBackground()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var memSub: String {
        let m = state.metrics
        guard m.memTotalBytes > 0 else { return "-- / -- GB" }
        return String(format: "%.1f / %.0f GB", Double(m.memUsedBytes) / 1_073_741_824, Double(m.memTotalBytes) / 1_073_741_824)
    }

    private var diskSub: String {
        let m = state.metrics
        guard m.diskTotalBytes > 0 else { return "-- / -- GB" }
        return String(format: "%.0f / %.0f GB", Double(m.diskUsedBytes) / 1_073_741_824, Double(m.diskTotalBytes) / 1_073_741_824)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "water.waves")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("系统状态").font(.system(size: 13, weight: .semibold))
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("实时").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(Self.timeString(ctx.date)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
    }

    private var cpuTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CPU").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text("\(state.metrics.coreCount) 核").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Fmt.percent(state.metrics.cpuPercent))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer()
            }
            ProgressView(value: min(max(state.metrics.cpuPercent, 0), 100), total: 100)
                .tint(tint(state.metrics.cpuPercent))
        }
        .padding(12)
        .background(tileBackground)
    }

    private func tile(title: String, value: String, sub: String, fraction: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(sub).font(.system(size: 10)).foregroundStyle(.secondary)
            ProgressView(value: min(max(fraction * 100, 0), 100), total: 100)
                .tint(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tileBackground)
    }

    private var netTile: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("上传").font(.system(size: 10)).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up").font(.system(size: 11, weight: .bold)).foregroundStyle(.purple)
                    Text(Fmt.rate(state.metrics.upBytesPerSec)).font(.system(size: 13, weight: .medium)).monospacedDigit()
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("下载").font(.system(size: 10)).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down").font(.system(size: 11, weight: .bold)).foregroundStyle(.cyan)
                    Text(Fmt.rate(state.metrics.downBytesPerSec)).font(.system(size: 13, weight: .medium)).monospacedDigit()
                }
            }
            Spacer()
        }
        .padding(12)
        .background(tileBackground)
    }

    private var procs: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TOP 进程").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text("按 CPU").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            ForEach(state.metrics.topProcesses.prefix(3)) { p in
                HStack(spacing: 8) {
                    Text(p.name).font(.system(size: 12)).lineLimit(1)
                    Spacer()
                    Text(Fmt.percent(p.cpuPercent)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(tileBackground)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            actionButton("清理", systemImage: "trash") { state.openMainSection?("clean") }
            actionButton("卸载", systemImage: "xmark.bin") { state.openMainSection?("uninstall") }
            actionButton("主界面", systemImage: "rectangle.on.rectangle", primary: true) { state.openMainWindow?() }
        }
    }

    private func actionButton(_ title: String, systemImage: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(primary ? Color.accentColor : Color.white.opacity(0.08))
            )
            .foregroundStyle(primary ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color.white.opacity(0.05))
    }

    private func tint(_ v: Double) -> Color {
        if v >= 85 { return .red }
        if v >= 60 { return .orange }
        return .green
    }

    private static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}