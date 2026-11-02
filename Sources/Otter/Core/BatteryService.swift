import Foundation

struct BatteryReport {
    var present = false
    var cycleCount: Int?
    var designCapacity: Int?
    var maxCapacity: Int?
    var healthPercent: Double?
    var temperatureC: Double?
    var charging = false
    var externalPower = false
}

enum BatteryService {
    static func read() -> BatteryReport {
        var report = BatteryReport()
        guard let out = run("/usr/sbin/ioreg", ["-r", "-c", "AppleSmartBattery", "-d", "1"]),
              out.contains("AppleSmartBattery") else { return report }
        report.present = true

        func intValue(_ key: String, in text: String) -> Int? {
            for line in text.split(separator: "\n") {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard s.hasPrefix("\"\(key)\"") else { continue }
                guard let eq = s.range(of: "=") else { continue }
                let rest = s[eq.upperBound...].trimmingCharacters(in: .whitespaces)
                let digits = rest.prefix { $0 == "-" || $0.isNumber }
                if let value = Int(digits) { return value }
            }
            return nil
        }

        func nestedInt(_ key: String, in text: String) -> Int? {
            guard let r = text.range(of: "\"\(key)\"=") else { return nil }
            let rest = text[r.upperBound...]
            let digits = rest.prefix { $0 == "-" || $0.isNumber }
            return Int(digits)
        }

        func boolValue(_ key: String, in text: String) -> Bool {
            text.range(of: "\"\(key)\" = Yes") != nil
        }

        report.cycleCount = intValue("CycleCount", in: out)
        report.charging = boolValue("IsCharging", in: out)
        report.externalPower = boolValue("ExternalConnected", in: out)

        // Apple Silicon 把容量放在 BatteryData 字典里。
        var batteryData = out
        if let range = out.range(of: "\"BatteryData\"") {
            batteryData = String(out[range.lowerBound...])
        }
        report.designCapacity = nestedInt("DesignCapacity", in: batteryData)
        report.maxCapacity = nestedInt("AppleRawMaxCapacity", in: batteryData)
        if let design = report.designCapacity, let max = report.maxCapacity, design > 0 {
            report.healthPercent = min(100, Double(max) / Double(design) * 100)
        }
        if let raw = intValue("Temperature", in: out), raw > 0 {
            report.temperatureC = raw > 1000 ? Double(raw) / 10 - 273.15 : Double(raw)
        }
        return report
    }

    private static func run(_ path: String, _ args: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return nil }
        return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}
