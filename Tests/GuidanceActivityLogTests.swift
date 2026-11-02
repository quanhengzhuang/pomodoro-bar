import Foundation

@main
struct GuidanceActivityLogTests {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pomodoro-activity-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("guidance-activity.json")
        let log = GuidanceActivityLog(url: url)
        let initialEvents = try log.load()
        precondition(initialEvents.isEmpty)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: Date())!
        let nextDay = calendar.date(byAdding: .hour, value: 1, to: date)!
        let first = try log.append(.opened, at: date)
        let dateKey = first[0].dateKey
        precondition(first[0].hour == 23)
        precondition(first[0].kind == .opened)

        _ = try log.append(.edited, at: date)
        _ = try log.append(.opened, at: date)
        let events = try log.append(.opened, at: nextDay)
        precondition(events.count == 4)
        precondition(events[3].dateKey != dateKey && events[3].hour == 0)
        let hours = GuidanceActivityLog.hours(on: dateKey, from: events)
        precondition(hours.count == 24 && hours[23] == .edited)
        precondition(hours[0] == nil)
        precondition(GuidanceActivityLog.hours(on: events[3].dateKey, from: events)[0] == .opened)

        let raw = try String(contentsOf: url, encoding: .utf8)
        precondition(raw.contains("\"occurredAt\"") && raw.hasSuffix("\n"))
        let corrupt = Data("invalid JSON".utf8)
        try corrupt.write(to: url)
        do {
            _ = try log.append(.edited, at: date)
            preconditionFailure("A corrupt log must never be replaced")
        } catch {
            let stillCorrupt = try Data(contentsOf: url)
            precondition(stillCorrupt == corrupt)
        }
        print("Guidance activity log tests passed")
    }
}
