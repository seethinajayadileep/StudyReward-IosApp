import Foundation
import Supabase

@MainActor
final class ProgressStore {

    static let shared = ProgressStore()

    struct ModuleRecord: Codable {
        var bestCorrect: Int
        var totalQuestions: Int
        var lastCompleted: Date
    }

    struct PendingAttempt: Codable {
        let id: UUID
        let userID: UUID
        let moduleID: String
        let correctCount: Int
        let totalQuestions: Int
        let completedAt: String
        let studyDay: String

        enum CodingKeys: String, CodingKey {
            case id
            case userID = "user_id"
            case moduleID = "module_id"
            case correctCount = "correct_count"
            case totalQuestions = "total_questions"
            case completedAt = "completed_at"
            case studyDay = "study_day"
        }
    }

    private struct ProgressData: Codable {
        var records: [String: ModuleRecord] = [:]
        var studyDays: [Date] = []
        var pendingAttempts: [PendingAttempt] = []

        enum CodingKeys: String, CodingKey {
            case records, studyDays, pendingAttempts
        }

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            records = try c.decodeIfPresent(
                [String: ModuleRecord].self, forKey: .records
            ) ?? [:]
            studyDays = try c.decodeIfPresent(
                [Date].self, forKey: .studyDays
            ) ?? []
            pendingAttempts = try c.decodeIfPresent(
                [PendingAttempt].self, forKey: .pendingAttempts
            ) ?? []
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(records, forKey: .records)
            try c.encode(studyDays, forKey: .studyDays)
            try c.encode(pendingAttempts, forKey: .pendingAttempts)
        }
    }

    enum SyncStatus {
        case complete, incomplete, busy, notSignedIn
    }

    struct SyncReport {
        let status: SyncStatus
        let pendingCount: Int
    }

    private let userKeyPrefix = "StudyReward.progress.v1.user."
    private let defaults: UserDefaults
    private let pageSize = 500
    private let maxPages = 200
    private var data = ProgressData()
    private var loadedKey: String?
    private var isSyncing = false
    private var isDownloading = false
    private var calendar: Calendar { Calendar.current }

    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Account and storage

    private func currentUserID() -> UUID? {
        return SupabaseManager.shared.client.auth.currentSession?.user.id
    }

    @discardableResult
    private func prepareCurrentUser() -> (key: String, userID: UUID)? {
        guard let userID = currentUserID() else {
            data = ProgressData()
            loadedKey = nil
            return nil
        }
        let key = userKeyPrefix + userID.uuidString.lowercased()
        if key == loadedKey { return (key, userID) }

        data = ProgressData()
        loadedKey = key
        if let saved = defaults.data(forKey: key) {
            do {
                var decoded = try JSONDecoder().decode(
                    ProgressData.self, from: saved
                )
                decoded.records = decoded.records.filter { _, r in
                    r.totalQuestions > 0 &&
                    r.bestCorrect >= 0 &&
                    r.bestCorrect <= r.totalQuestions
                }
                data = decoded
            } catch {
                let backupKey = key + ".backup"
                if defaults.data(forKey: backupKey) == nil {
                    defaults.set(saved, forKey: backupKey)
                }
                print("ProgressStore: unreadable progress backed up.")
            }
        }
        return (key, userID)
    }

    private func save(_ updated: ProgressData, key: String) -> Bool {
        do {
            defaults.set(try JSONEncoder().encode(updated), forKey: key)
            data = updated
            return true
        } catch {
            print("ProgressStore: could not encode progress.")
            return false
        }
    }

    private static func isValid(
        moduleID: String, correct: Int, total: Int
    ) -> Bool {
        let trimmed = moduleID.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && moduleID.count <= 100
            && (1...100).contains(total)
            && correct >= 0 && correct <= total
    }

    private static func apply(
        _ correct: Int, of total: Int, at date: Date,
        module: String, to data: inout ProgressData
    ) {
        guard let old = data.records[module] else {
            data.records[module] = ModuleRecord(
                bestCorrect: correct,
                totalQuestions: total,
                lastCompleted: date
            )
            return
        }
        let newScore = Double(correct) / Double(total)
        let oldScore = Double(old.bestCorrect) / Double(old.totalQuestions)
        let latest = max(old.lastCompleted, date)

        if newScore > oldScore ||
            (newScore == oldScore && correct > old.bestCorrect) {
            data.records[module] = ModuleRecord(
                bestCorrect: correct,
                totalQuestions: total,
                lastCompleted: latest
            )
        } else {
            data.records[module]?.lastCompleted = latest
        }
    }

    // MARK: - Save a finished quiz

    @discardableResult
    func recordQuiz(
        moduleID: String,
        correctCount: Int,
        totalQuestions: Int,
        date: Date = Date()
    ) -> Bool {
        guard ProgressStore.isValid(
            moduleID: moduleID,
            correct: correctCount,
            total: totalQuestions
        ), let user = prepareCurrentUser() else { return false }

        var updated = data
        ProgressStore.apply(
            correctCount, of: totalQuestions, at: date,
            module: moduleID, to: &updated
        )

        let day = calendar.startOfDay(for: date)
        if !updated.studyDays.contains(day) {
            updated.studyDays.append(day)
        }
        updated.pendingAttempts.append(PendingAttempt(
            id: UUID(),
            userID: user.userID,
            moduleID: moduleID,
            correctCount: correctCount,
            totalQuestions: totalQuestions,
            completedAt: ISO8601DateFormatter().string(from: date),
            studyDay: dayFormatter.string(from: date)
        ))

        guard save(updated, key: user.key) else { return false }
        Task { await self.syncPendingAttempts() }
        return true
    }

    // MARK: - Upload

    var pendingUploadCount: Int {
        guard let user = prepareCurrentUser() else { return 0 }
        return data.pendingAttempts.filter {
            $0.userID == user.userID
        }.count
    }

    @discardableResult
    func syncPendingAttempts() async -> Bool {
        guard !isSyncing, let user = prepareCurrentUser() else { return false }
        isSyncing = true
        defer { isSyncing = false }

        while let attempt = data.pendingAttempts.first(
            where: { $0.userID == user.userID }
        ) {
            guard currentUserID() == user.userID else { return false }
            do {
                try await SupabaseManager.shared.client
                    .from("quiz_attempts")
                    .upsert(
                        attempt,
                        onConflict: "id",
                        returning: .minimal,
                        ignoreDuplicates: true
                    )
                    .execute()
            } catch {
                print("ProgressStore: upload failed; attempt stays queued.")
                return false
            }

            guard currentUserID() == user.userID,
                  prepareCurrentUser()?.key == user.key else { return false }
            var updated = data
            updated.pendingAttempts.removeAll { $0.id == attempt.id }
            guard save(updated, key: user.key) else { return false }
        }
        return true
    }

    // MARK: - Download and merge

    func syncCloudProgress() async -> SyncReport {
        guard let user = prepareCurrentUser() else {
            return SyncReport(status: .notSignedIn, pendingCount: 0)
        }
        guard !isDownloading else {
            return SyncReport(status: .busy, pendingCount: pendingUploadCount)
        }
        isDownloading = true
        defer { isDownloading = false }

        let uploadOK = await syncPendingAttempts()
        var cloudRows: [PendingAttempt] = []
        var reachedEnd = false

        do {
            var page = 0
            while page < maxPages {
                guard currentUserID() == user.userID else { break }
                let from = page * pageSize
                let rows: [PendingAttempt] = try await SupabaseManager.shared.client
                    .from("quiz_attempts")
                    .select("id,user_id,module_id,correct_count,total_questions,completed_at,study_day")
                    .eq("user_id", value: user.userID)
                    .order("completed_at", ascending: true)
                    .order("id", ascending: true)
                    .range(from: from, to: from + pageSize - 1)
                    .execute()
                    .value

                cloudRows.append(contentsOf: rows)
                if rows.count < pageSize {
                    reachedEnd = true
                    break
                }
                page += 1
            }
        } catch {
            print("ProgressStore: download failed; will retry later.")
        }

        var downloadOK = false
        if reachedEnd,
           currentUserID() == user.userID,
           prepareCurrentUser()?.key == user.key {
            let merged = ProgressStore.merge(
                cloudRows, into: data, userID: user.userID,
                calendar: calendar, dayFormatter: dayFormatter
            )
            downloadOK = save(merged, key: user.key)
        }

        guard currentUserID() == user.userID else {
            return SyncReport(status: .incomplete, pendingCount: 0)
        }
        let pending = pendingUploadCount
        let done = uploadOK && downloadOK && pending == 0
        return SyncReport(
            status: done ? .complete : .incomplete,
            pendingCount: pending
        )
    }

    private static func merge(
        _ rows: [PendingAttempt], into original: ProgressData,
        userID: UUID, calendar: Calendar, dayFormatter: DateFormatter
    ) -> ProgressData {
        var result = original
        var days = Set(result.studyDays.map { calendar.startOfDay(for: $0) })

        for row in rows {
            guard row.userID == userID,
                  isValid(moduleID: row.moduleID,
                          correct: row.correctCount,
                          total: row.totalQuestions),
                  let dayDate = dayFormatter.date(from: row.studyDay),
                  dayFormatter.string(from: dayDate) == row.studyDay,
                  let completed = parseTimestamp(row.completedAt) else { continue }

            let day = calendar.startOfDay(for: dayDate)
            if !days.contains(day) {
                days.insert(day)
                result.studyDays.append(day)
            }
            apply(
                row.correctCount, of: row.totalQuestions, at: completed,
                module: row.moduleID, to: &result
            )
        }
        return result
    }

    private static func parseTimestamp(_ text: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: text) { return date }

        if let range = text.range(of: #"\.\d+"#, options: .regularExpression) {
            var trimmed = text
            trimmed.removeSubrange(range)
            return plain.date(from: trimmed)
        }
        return nil
    }

    // MARK: - Read local progress

    func bestRecord(for moduleID: String) -> ModuleRecord? {
        prepareCurrentUser()
        return data.records[moduleID]
    }

    func isCompleted(moduleID: String) -> Bool {
        prepareCurrentUser()
        return data.records[moduleID] != nil
    }

    var completedModuleCount: Int {
        prepareCurrentUser()
        return data.records.count
    }

    var totalPoints: Int {
        prepareCurrentUser()
        return data.records.values.reduce(0) { $0 + $1.bestCorrect * 10 }
    }

    var overallPercentage: Int {
        prepareCurrentUser()
        let correct = data.records.values.reduce(0) { $0 + $1.bestCorrect }
        let total = data.records.values.reduce(0) { $0 + $1.totalQuestions }
        return total > 0 ? correct * 100 / total : 0
    }

    var currentStreak: Int {
        prepareCurrentUser()
        let days = Set(data.studyDays.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: Date())

        if !days.contains(day) {
            guard let yesterday = calendar.date(
                byAdding: .day, value: -1, to: day
            ) else { return 0 }
            day = calendar.startOfDay(for: yesterday)
            guard days.contains(day) else { return 0 }
        }

        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(
                byAdding: .day, value: -1, to: day
            ) else { break }
            day = calendar.startOfDay(for: previous)
        }
        return streak
    }
}
