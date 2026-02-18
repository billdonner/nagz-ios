import Foundation
import GRDB

/// On-device AI service using local GRDB cache with heuristic logic.
///
/// When the cache is fresh (<24h), runs heuristic AI locally.
/// Falls back to `ServerAIService` when cache is stale or data unavailable.
actor OnDeviceAIService: AIService {
    private let db: DatabaseManager
    private let fallback: ServerAIService
    private let staleCacheThreshold: TimeInterval = 24 * 60 * 60

    init(db: DatabaseManager, fallback: ServerAIService) {
        self.db = db
        self.fallback = fallback
    }

    // MARK: - AIService

    func summarizeExcuse(_ text: String, nagId: UUID) async throws -> ExcuseSummaryResponse {
        let summary = String(text.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        let (category, confidence) = classifyExcuse(text)
        return ExcuseSummaryResponse(
            nagId: nagId, summary: summary,
            category: category, confidence: confidence
        )
    }

    func selectTone(nagId: UUID) async throws -> ToneSelectResponse {
        guard try await isCacheFresh() else {
            return try await fallback.selectTone(nagId: nagId)
        }

        let nagIdStr = nagId.uuidString
        let reader = await db.reader

        guard let nag = try await reader.read({ db in
            try CachedNag.filter(Column("id") == nagIdStr).fetchOne(db)
        }) else {
            return try await fallback.selectTone(nagId: nagId)
        }

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        let missCount = try await reader.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM cached_nag_events e
                JOIN cached_nags n ON e.nagId = n.id
                WHERE n.recipientId = ? AND n.familyId = ?
                AND e.eventType = 'nag_missed' AND e.at >= ?
                """, arguments: [nag.recipientId, nag.familyId, sevenDaysAgo]) ?? 0
        }

        let streak = try await reader.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COALESCE(SUM(streakDelta), 0) FROM cached_gamification_events
                WHERE userId = ? AND familyId = ?
                """, arguments: [nag.recipientId, nag.familyId]) ?? 0
        }

        let tone: AITone
        let reason: String
        if missCount >= 3 {
            tone = .firm
            reason = "\(missCount) misses in last 7 days"
        } else if missCount == 0 && streak >= 3 {
            tone = .supportive
            reason = "No misses and \(streak)-day streak"
        } else {
            tone = .neutral
            reason = "Default tone"
        }

        return ToneSelectResponse(
            nagId: nagId, tone: tone,
            missCount7D: missCount, streak: streak, reason: reason
        )
    }

    func coaching(nagId: UUID) async throws -> CoachingResponse {
        let tips: [(scenario: String, tip: String, category: String)] = [
            ("default", "Stay on track by checking your tasks at the start of each day.", "general"),
            ("first_miss", "Missing a task happens! Try setting a reminder 30 minutes before it's due.", "time_management"),
            ("streak_3", "Great job keeping your streak going! Consistency builds habits.", "motivation"),
        ]
        let selected = tips.randomElement() ?? tips[0]
        return CoachingResponse(
            nagId: nagId, tip: selected.tip,
            category: selected.category, scenario: selected.scenario
        )
    }

    func patterns(userId: UUID, familyId: UUID) async throws -> PatternsResponse {
        guard try await isCacheFresh() else {
            return try await fallback.patterns(userId: userId, familyId: familyId)
        }

        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let reader = await db.reader

        let dates = try await reader.read { db -> [Date] in
            try Date.fetchAll(db, sql: """
                SELECT e.at FROM cached_nag_events e
                JOIN cached_nags n ON e.nagId = n.id
                WHERE n.recipientId = ? AND n.familyId = ?
                AND e.eventType = 'nag_missed' AND e.at >= ?
                """, arguments: [userId.uuidString, familyId.uuidString, ninetyDaysAgo])
        }

        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        var weekdayCounts = [Int: Int]()
        let calendar = Calendar.current
        for date in dates {
            let weekday = calendar.component(.weekday, from: date)
            weekdayCounts[weekday, default: 0] += 1
        }

        let insights = weekdayCounts
            .filter { $0.value >= 3 }
            .sorted { $0.key < $1.key }
            .map { InsightItem(dayOfWeek: dayNames[$0.key - 1], missCount: $0.value) }

        return PatternsResponse(
            userId: userId, familyId: familyId,
            insights: insights, analyzedAt: Date()
        )
    }

    func digest(familyId: UUID) async throws -> DigestResponse {
        try await fallback.digest(familyId: familyId)
    }

    func predictCompletion(nagId: UUID) async throws -> PredictCompletionResponse {
        guard try await isCacheFresh() else {
            return try await fallback.predictCompletion(nagId: nagId)
        }

        let nagIdStr = nagId.uuidString
        let reader = await db.reader

        guard let nag = try await reader.read({ db in
            try CachedNag.filter(Column("id") == nagIdStr).fetchOne(db)
        }) else {
            return try await fallback.predictCompletion(nagId: nagId)
        }

        let catStats = try await reader.read { db -> (total: Int, completed: Int) in
            let total = try CachedNag
                .filter(Column("recipientId") == nag.recipientId)
                .filter(Column("familyId") == nag.familyId)
                .filter(Column("category") == nag.category)
                .filter(Column("id") != nagIdStr)
                .fetchCount(db)
            let completed = try CachedNag
                .filter(Column("recipientId") == nag.recipientId)
                .filter(Column("familyId") == nag.familyId)
                .filter(Column("category") == nag.category)
                .filter(Column("id") != nagIdStr)
                .filter(Column("status") == "completed")
                .fetchCount(db)
            return (total, completed)
        }

        let allStats = try await reader.read { db -> (total: Int, completed: Int) in
            let total = try CachedNag
                .filter(Column("recipientId") == nag.recipientId)
                .filter(Column("familyId") == nag.familyId)
                .filter(Column("id") != nagIdStr)
                .fetchCount(db)
            let completed = try CachedNag
                .filter(Column("recipientId") == nag.recipientId)
                .filter(Column("familyId") == nag.familyId)
                .filter(Column("id") != nagIdStr)
                .filter(Column("status") == "completed")
                .fetchCount(db)
            return (total, completed)
        }

        let catRate = catStats.total > 0 ? Double(catStats.completed) / Double(catStats.total) : 0.5
        let overallRate = allStats.total > 0 ? Double(allStats.completed) / Double(allStats.total) : 0.5
        let likelihood = (catRate * 0.6 + overallRate * 0.4).rounded(to: 2)

        var suggestedTime: Date? = nil
        if nag.status == "open" {
            let offset: TimeInterval = likelihood >= 0.5 ? -30 * 60 : -60 * 60
            suggestedTime = nag.dueAt.addingTimeInterval(offset)
        }

        return PredictCompletionResponse(
            nagId: nagId,
            likelihood: likelihood,
            suggestedReminderTime: suggestedTime,
            factors: [
                CompletionFactor(name: "category_rate", value: catRate.rounded(to: 2)),
                CompletionFactor(name: "overall_rate", value: overallRate.rounded(to: 2)),
            ]
        )
    }

    func pushBack(nagId: UUID) async throws -> PushBackResponse {
        try await fallback.pushBack(nagId: nagId)
    }

    // MARK: - Private

    private func isCacheFresh() async throws -> Bool {
        let reader = await db.reader
        let meta = try await reader.read { db in
            try SyncMetadata.filter(Column("entity") == "all").fetchOne(db)
        }
        guard let meta else { return false }
        return Date().timeIntervalSince(meta.lastSyncAt) < staleCacheThreshold
    }

    private func classifyExcuse(_ text: String) -> (ExcuseCategory, Double) {
        let lower = text.lowercased()
        let keywords: [(String, ExcuseCategory)] = [
            ("forgot", .forgot), ("remember", .forgot), ("memory", .forgot),
            ("busy", .timeConflict), ("time", .timeConflict), ("schedule", .timeConflict), ("late", .timeConflict),
            ("confus", .unclearInstructions), ("understand", .unclearInstructions), ("unclear", .unclearInstructions),
            ("need", .lackingResources), ("don't have", .lackingResources), ("missing", .lackingResources),
            ("won't", .refused), ("refuse", .refused), ("don't want", .refused),
        ]
        for (keyword, category) in keywords {
            if lower.contains(keyword) {
                return (category, 0.7)
            }
        }
        return (.other, 0.3)
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}
