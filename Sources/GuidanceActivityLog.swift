import Foundation

/// 行为发生的本地日期和小时在写入时固定，日后切换时区也不会改变活动分组。
enum GuidanceActivityKind: String, Codable {
    case opened
    case edited
}

struct GuidanceActivityEvent: Codable {
    let kind: GuidanceActivityKind
    let occurredAt: Date
    let dateKey: String
    let hour: Int
}

/// 只存活动，不改 daily-guidance.json；损坏的日志会抛错，绝不静默覆盖。
struct GuidanceActivityLog {
    let url: URL

    func load() throws -> [GuidanceActivityEvent] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([GuidanceActivityEvent].self, from: Data(contentsOf: url))
    }

    @discardableResult
    func append(_ kind: GuidanceActivityKind, at date: Date = Date()) throws -> [GuidanceActivityEvent] {
        var events = try load()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        events.append(GuidanceActivityEvent(
            kind: kind,
            occurredAt: date,
            dateKey: formatter.string(from: date),
            hour: calendar.component(.hour, from: date)
        ))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var data = try encoder.encode(events)
        data.append(0x0A)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return events
    }

    /// 每个小时最多一个状态；同一小时内编写优先于打开。
    static func hours(on dateKey: String, from events: [GuidanceActivityEvent]) -> [GuidanceActivityKind?] {
        var hours = [GuidanceActivityKind?](repeating: nil, count: 24)
        for event in events where event.dateKey == dateKey && (0..<24).contains(event.hour) {
            if event.kind == .edited || hours[event.hour] == nil {
                hours[event.hour] = event.kind
            }
        }
        return hours
    }
}
