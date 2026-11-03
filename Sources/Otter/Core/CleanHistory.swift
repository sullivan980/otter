import Foundation
import Combine

struct CleanHistoryEvent: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var kind: String          // clean | space | uninstall
    var freedBytes: Int64
    var trashedBytes: Int64
    var items: Int
    var note: String
}

/// 清理历史 / 空间账本：~/.Library/Application Support/Otter/history.json
final class CleanHistoryStore: ObservableObject {
    static let shared = CleanHistoryStore()
    static var testURL: URL?

    @Published private(set) var events: [CleanHistoryEvent] = []

    private init() { load() }

    var fileURL: URL {
        if let test = Self.testURL { return test }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Otter/history.json")
    }

    func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? decoder.decode([CleanHistoryEvent].self, from: data) else {
            events = []
            return
        }
        events = list.sorted { $0.date > $1.date }
    }

    func add(kind: String, freedBytes: Int64, trashedBytes: Int64, items: Int, note: String = "") {
        let event = CleanHistoryEvent(date: Date(), kind: kind, freedBytes: freedBytes,
                                      trashedBytes: trashedBytes, items: items, note: note)
        events.insert(event, at: 0)
        if events.count > 200 { events = Array(events.prefix(200)) }
        persist()
    }

    func clear() {
        events = []
        persist()
    }

    var totalFreed: Int64 { events.reduce(0) { $0 + $1.freedBytes } }
    var totalTrashed: Int64 { events.reduce(0) { $0 + $1.trashedBytes } }

    private func persist() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(events) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}