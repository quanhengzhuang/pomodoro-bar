// macOS 与 iOS 共用的 CloudKit 数据层。
//
// 这里只描述云端记录的字段和批量读写，不持有任何界面状态。两个平台仍保留
// JSON 作为本地备份，并在各自的 Store/Controller 中负责合并与错误提示。
import CloudKit
import Foundation

/// CloudKit Container 必须与 macOS/iOS entitlements 中的值完全一致。
let pomodoroCloudKitContainerIdentifier = "iCloud.local.codex.PomodoroBar"

/// 云端的一条已完成计时。字符串日期与原 JSON 保持同一语义。
struct CloudPomodoroSession: Hashable, Sendable {
    let recordID: String
    let startedAt: String
    let endedAt: String
    let date: String
    let type: String
    let durationSeconds: Int
    let note: String
}

/// 云端的一天指引。`modifiedAt` 用来选择多设备中最新的文本。
struct CloudDailyGuidance: Hashable, Sendable {
    let dateKey: String
    let text: String
    let modifiedAt: Date
}

/// 一次云端读取得到的完整数据快照。
struct PomodoroCloudSnapshot: Sendable {
    let sessions: [CloudPomodoroSession]
    let guidance: [CloudDailyGuidance]
}

/// CloudKit 本身没有 SQL 表；这两个 Record Type 会在开发环境首次写入时生成。
private enum CloudSchema {
    static let sessionType = "PomodoroSession"
    static let guidanceType = "DailyGuidance"
    static let schemaVersion: Int64 = 1

    enum SessionField {
        static let startedAt = "startedAt"
        static let endedAt = "endedAt"
        static let date = "date"
        static let type = "type"
        static let durationSeconds = "durationSeconds"
        static let note = "note"
        static let schemaVersion = "schemaVersion"
    }

    enum GuidanceField {
        static let dateKey = "dateKey"
        static let text = "text"
        static let modifiedAt = "modifiedAt"
        static let schemaVersion = "schemaVersion"
    }
}

/// 查询、分页和批量保存的最小封装。
///
/// 使用 Private Database，因此数据只对当前 iCloud 账户可见。类型标记为
/// `@unchecked Sendable` 是因为 CKContainer/CKDatabase 由系统负责线程安全，且本类没有可变共享状态。
final class PomodoroCloudKitStore: @unchecked Sendable {
    private let database: CKDatabase

    init(container: CKContainer = CKContainer(identifier: pomodoroCloudKitContainerIdentifier)) {
        database = container.privateCloudDatabase
    }

    /// 并行读取完成记录和每日指引。新容器尚未建立 Record Type 时按空数据处理。
    func fetchSnapshot() async throws -> PomodoroCloudSnapshot {
        async let sessions = fetchSessions()
        async let guidance = fetchGuidance()
        return try await PomodoroCloudSnapshot(sessions: sessions, guidance: guidance)
    }

    /// 写入不可变的已完成记录。相同 recordID 已存在时直接跳过，不会重复追加。
    func saveSessions(_ sessions: [CloudPomodoroSession]) async throws {
        for batch in sessions.chunked(maxCount: 200) {
            try await retryingRecordConflicts {
                let recordIDs = batch.map { CKRecord.ID(recordName: $0.recordID) }
                let existing = try await fetchExistingRecords(recordIDs)
                let records = batch.compactMap { value -> CKRecord? in
                    let recordID = CKRecord.ID(recordName: value.recordID)
                    // 已完成记录不可变；同 ID 已存在即表示这条记录已经上传成功。
                    guard existing[recordID] == nil else { return nil }
                    let record = CKRecord(recordType: CloudSchema.sessionType, recordID: recordID)
                    apply(value, to: record)
                    return record
                }
                try await modify(records)
            }
        }
    }

    /// 按日期覆盖同一天的指引；冲突选择由调用方在写入前根据 modifiedAt 完成。
    func saveGuidance(_ entries: [CloudDailyGuidance]) async throws {
        for batch in entries.chunked(maxCount: 200) {
            try await retryingRecordConflicts {
                let recordIDs = batch.map { CKRecord.ID(recordName: $0.dateKey) }
                let existing = try await fetchExistingRecords(recordIDs)
                let records = batch.compactMap { value -> CKRecord? in
                    let recordID = CKRecord.ID(recordName: value.dateKey)
                    let record = existing[recordID]
                        ?? CKRecord(recordType: CloudSchema.guidanceType, recordID: recordID)
                    let serverModifiedAt = record[CloudSchema.GuidanceField.modifiedAt] as? Date
                        ?? record.modificationDate
                        ?? .distantPast
                    // 旧设备的延迟上传不能覆盖另一台设备更新的内容。
                    guard existing[recordID] == nil || value.modifiedAt > serverModifiedAt else {
                        return nil
                    }
                    apply(value, to: record)
                    return record
                }
                try await modify(records)
            }
        }
    }

    func fetchSessions() async throws -> [CloudPomodoroSession] {
        do {
            return try await fetchAll(recordType: CloudSchema.sessionType).compactMap { record in
                guard let startedAt = record[CloudSchema.SessionField.startedAt] as? String,
                      let endedAt = record[CloudSchema.SessionField.endedAt] as? String,
                      let date = record[CloudSchema.SessionField.date] as? String,
                      let type = record[CloudSchema.SessionField.type] as? String,
                      let duration = record[CloudSchema.SessionField.durationSeconds] as? NSNumber else {
                    return nil
                }
                return CloudPomodoroSession(
                    recordID: record.recordID.recordName,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    date: date,
                    type: type,
                    durationSeconds: duration.intValue,
                    note: record[CloudSchema.SessionField.note] as? String ?? ""
                )
            }
        } catch where isMissingDevelopmentSchema(error) {
            return []
        }
    }

    func fetchGuidance() async throws -> [CloudDailyGuidance] {
        do {
            return try await fetchAll(recordType: CloudSchema.guidanceType).compactMap { record in
                guard let dateKey = record[CloudSchema.GuidanceField.dateKey] as? String,
                      let text = record[CloudSchema.GuidanceField.text] as? String else {
                    return nil
                }
                let modifiedAt = record[CloudSchema.GuidanceField.modifiedAt] as? Date
                    ?? record.modificationDate
                    ?? .distantPast
                return CloudDailyGuidance(dateKey: dateKey, text: text, modifiedAt: modifiedAt)
            }
        } catch where isMissingDevelopmentSchema(error) {
            return []
        }
    }

    /// CKQuery 单次有数量上限，必须沿 cursor 读到结束。
    private func fetchAll(recordType: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let firstPage = try await retrying {
            let page = try await database.records(matching: query, resultsLimit: 200)
            return (try successfulRecords(from: page.matchResults), page.queryCursor)
        }
        var records = firstPage.0
        var cursor = firstPage.1

        while let currentCursor = cursor {
            let nextPage = try await retrying {
                let page = try await database.records(
                    continuingMatchFrom: currentCursor,
                    resultsLimit: 200
                )
                return (try successfulRecords(from: page.matchResults), page.queryCursor)
            }
            records.append(contentsOf: nextPage.0)
            cursor = nextPage.1
        }
        return records
    }

    /// 一个分页中单条失败也必须抛出，避免把“部分读取”误当完整快照回写。
    private func successfulRecords(
        from results: [(CKRecord.ID, Result<CKRecord, Error>)]
    ) throws -> [CKRecord] {
        try results.map { try $0.1.get() }
    }

    private func apply(_ value: CloudPomodoroSession, to record: CKRecord) {
        record[CloudSchema.SessionField.startedAt] = value.startedAt as CKRecordValue
        record[CloudSchema.SessionField.endedAt] = value.endedAt as CKRecordValue
        record[CloudSchema.SessionField.date] = value.date as CKRecordValue
        record[CloudSchema.SessionField.type] = value.type as CKRecordValue
        record[CloudSchema.SessionField.durationSeconds] = NSNumber(value: value.durationSeconds)
        record[CloudSchema.SessionField.note] = value.note as CKRecordValue
        record[CloudSchema.SessionField.schemaVersion] = NSNumber(value: CloudSchema.schemaVersion)
    }

    private func apply(_ value: CloudDailyGuidance, to record: CKRecord) {
        record[CloudSchema.GuidanceField.dateKey] = value.dateKey as CKRecordValue
        record[CloudSchema.GuidanceField.text] = value.text as CKRecordValue
        record[CloudSchema.GuidanceField.modifiedAt] = value.modifiedAt as CKRecordValue
        record[CloudSchema.GuidanceField.schemaVersion] = NSNumber(value: CloudSchema.schemaVersion)
    }

    /// 批量取回现有 recordChangeTag，避免用一个新建 CKRecord 覆盖同 ID 记录时产生冲突。
    private func fetchExistingRecords(_ recordIDs: [CKRecord.ID]) async throws -> [CKRecord.ID: CKRecord] {
        guard !recordIDs.isEmpty else { return [:] }
        return try await retrying {
            let results = try await database.records(for: recordIDs)
            var existing: [CKRecord.ID: CKRecord] = [:]
            for (recordID, result) in results {
                switch result {
                case .success(let record):
                    existing[recordID] = record
                case .failure(let error) where isUnknownItem(error):
                    continue
                case .failure(let error):
                    throw error
                }
            }
            return existing
        }
    }

    /// 非原子批量写入使已经成功的记录得以保留；任一失败仍抛出，随后会重新拉取并合并。
    private func modify(_ records: [CKRecord]) async throws {
        guard !records.isEmpty else { return }
        try await retrying {
            let result = try await database.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: .changedKeys,
                atomically: false
            )
            for saveResult in result.saveResults.values {
                _ = try saveResult.get()
            }
        }
    }

    /// 两台设备同时首次写入同一 ID 时重新读取最新 changeTag，再按业务时间决定是否保存。
    private func retryingRecordConflicts(_ operation: () async throws -> Void) async throws {
        var attempt = 0
        while true {
            do {
                try await operation()
                return
            } catch {
                guard attempt < 2, containsOnlyServerRecordConflicts(error) else { throw error }
                attempt += 1
            }
        }
    }

    /// 遵循 CloudKit 返回的 retry-after，对限流、服务繁忙和短暂网络失败最多重试两次。
    private func retrying<T>(_ operation: () async throws -> T) async throws -> T {
        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch {
                guard attempt < 2, let delay = retryDelay(for: error, attempt: attempt) else {
                    throw error
                }
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func retryDelay(for error: Error, attempt: Int) -> TimeInterval? {
        guard let cloudError = error as? CKError else { return nil }
        if cloudError.code == .partialFailure,
           let partialErrors = cloudError.partialErrorsByItemID,
           !partialErrors.isEmpty {
            let delays = partialErrors.values.compactMap {
                retryDelay(for: $0, attempt: attempt)
            }
            guard delays.count == partialErrors.count else { return nil }
            return delays.max()
        }
        let retryableCodes: Set<CKError.Code> = [
            .networkFailure,
            .networkUnavailable,
            .requestRateLimited,
            .serviceUnavailable,
            .zoneBusy
        ]
        guard retryableCodes.contains(cloudError.code) else { return nil }
        return cloudError.userInfo[CKErrorRetryAfterKey] as? TimeInterval
            ?? TimeInterval(attempt + 1)
    }

    /// 开发环境在第一次写入前查询不存在的 Record Type 会返回 unknownItem。
    private func isMissingDevelopmentSchema(_ error: Error) -> Bool {
        guard let cloudError = error as? CKError else { return false }
        if cloudError.code == .unknownItem { return true }
        guard cloudError.code == .partialFailure,
              let partialErrors = cloudError.partialErrorsByItemID else {
            return false
        }
        return !partialErrors.isEmpty && partialErrors.values.allSatisfy {
            ($0 as? CKError)?.code == .unknownItem
        }
    }

    private func isUnknownItem(_ error: Error) -> Bool {
        (error as? CKError)?.code == .unknownItem
    }

    private func containsOnlyServerRecordConflicts(_ error: Error) -> Bool {
        guard let cloudError = error as? CKError else { return false }
        if cloudError.code == .serverRecordChanged { return true }
        guard cloudError.code == .partialFailure,
              let partialErrors = cloudError.partialErrorsByItemID,
              !partialErrors.isEmpty else {
            return false
        }
        return partialErrors.values.allSatisfy {
            ($0 as? CKError)?.code == .serverRecordChanged
        }
    }
}

private extension Array {
    func chunked(maxCount: Int) -> [[Element]] {
        guard maxCount > 0 else { return [] }
        return stride(from: 0, to: count, by: maxCount).map { start in
            Array(self[start..<Swift.min(start + maxCount, count)])
        }
    }
}

/// 为没有 UUID 的旧 JSON 记录生成跨设备稳定 ID。
///
/// 使用两组 64 位 FNV-1a 而非 Swift `Hasher`，因为后者每次进程启动都会随机化，
/// 不能用于 CloudKit recordName。新记录直接使用 UUID，只有旧数据走本函数。
func stableLegacyPomodoroRecordID(
    startedAt: String,
    endedAt: String,
    type: String,
    durationSeconds: Int,
    note: String
) -> String {
    let value = [startedAt, endedAt, type, String(durationSeconds), note].joined(separator: "\u{1F}")
    var first: UInt64 = 0xcbf29ce484222325
    var second: UInt64 = 0x84222325cbf29ce4
    for byte in value.utf8 {
        first = (first ^ UInt64(byte)) &* 0x100000001b3
        second = (second ^ UInt64(byte &+ 31)) &* 0x100000001b3
    }
    return String(format: "legacy-%016llx%016llx", first, second)
}
