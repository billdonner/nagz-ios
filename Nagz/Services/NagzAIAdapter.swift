import Foundation
import GRDB
import NagzAI

/// Adapter that bridges the NagzAI package with the app's AIService protocol.
///
/// Fetches context from GRDB cache, calls NagzAI Router, maps results back to app types.
/// When cache is stale or data unavailable, falls back to ServerAIService.
actor NagzAIAdapter: AIService {
    private let db: DatabaseManager
    private let fallback: ServerAIService
    private let router: NagzAI.Router
    private let staleCacheThreshold: TimeInterval = 24 * 60 * 60

    init(db: DatabaseManager, fallback: ServerAIService, preferHeuristic: Bool = false) {
        self.db = db
        self.fallback = fallback
        self.router = NagzAI.Router(preferHeuristic: preferHeuristic)
    }

    // MARK: - AIService

    func summarizeExcuse(_ text: String, nagId: UUID) async throws -> ExcuseSummaryResponse {
        let result = try await router.summarizeExcuse(text)
        return ExcuseSummaryResponse(
            nagId: nagId,
            summary: result.summary,
            category: bridgeExcuseCategory(result.category),
            confidence: result.confidence
        )
    }

    func selectTone(nagId: UUID) async throws -> ToneSelectResponse {
        guard let context = try await buildAIContext(nagId: nagId) else {
            return try await fallback.selectTone(nagId: nagId)
        }
        let result = try await router.selectTone(context: context)
        return ToneSelectResponse(
            nagId: nagId,
            tone: bridgeTone(result.tone),
            missCount7D: result.missCount7D,
            streak: result.streak,
            reason: result.reason
        )
    }

    func coaching(nagId: UUID) async throws -> CoachingResponse {
        guard let context = try await buildAIContext(nagId: nagId) else {
            return try await fallback.coaching(nagId: nagId)
        }
        let result = try await router.coaching(context: context)
        return CoachingResponse(
            nagId: nagId,
            tip: result.tip,
            category: result.category,
            scenario: result.scenario
        )
    }

    func patterns(userId: UUID, familyId: UUID) async throws -> PatternsResponse {
        guard try await isCacheFresh() else {
            return try await fallback.patterns(userId: userId, familyId: familyId)
        }
        let context = try await buildPatternsContext(userId: userId, familyId: familyId)
        let result = try await router.patterns(context: context)
        return PatternsResponse(
            userId: userId,
            familyId: familyId,
            insights: result.insights.map { InsightItem(dayOfWeek: $0.dayOfWeek, missCount: $0.missCount) },
            analyzedAt: result.analyzedAt
        )
    }

    func digest(familyId: UUID) async throws -> DigestResponse {
        guard try await isCacheFresh() else {
            return try await fallback.digest(familyId: familyId)
        }
        guard let context = try await buildDigestContext(familyId: familyId) else {
            return try await fallback.digest(familyId: familyId)
        }
        let result = try await router.digest(context: context)
        return DigestResponse(
            familyId: familyId,
            periodStart: result.periodStart,
            periodEnd: result.periodEnd,
            summaryText: result.summaryText,
            memberSummaries: result.memberSummaries.map {
                MemberSummary(
                    userId: $0.userId,
                    displayName: $0.displayName,
                    totalNags: $0.totalNags,
                    completed: $0.completed,
                    missed: $0.missed,
                    completionRate: $0.completionRate
                )
            },
            totals: DigestTotals(
                totalNags: result.totals.totalNags,
                completed: result.totals.completed,
                missed: result.totals.missed,
                open: result.totals.open,
                completionRate: result.totals.completionRate
            )
        )
    }

    func predictCompletion(nagId: UUID) async throws -> PredictCompletionResponse {
        guard let context = try await buildAIContext(nagId: nagId) else {
            return try await fallback.predictCompletion(nagId: nagId)
        }
        let result = try await router.predictCompletion(context: context)
        return PredictCompletionResponse(
            nagId: nagId,
            likelihood: result.likelihood,
            suggestedReminderTime: result.suggestedReminderTime,
            factors: result.factors.map { CompletionFactor(name: $0.name, value: $0.value) }
        )
    }

    func pushBack(nagId: UUID) async throws -> PushBackResponse {
        guard let context = try await buildAIContext(nagId: nagId) else {
            return try await fallback.pushBack(nagId: nagId)
        }
        let result = try await router.pushBack(context: context)
        return PushBackResponse(
            nagId: nagId,
            shouldPushBack: result.shouldPushBack,
            message: result.message,
            tone: result.tone.map { bridgeTone($0) },
            reason: result.reason
        )
    }

    // MARK: - Cache Freshness

    private func isCacheFresh() async throws -> Bool {
        let reader = await db.reader
        let meta = try await reader.read { db in
            try SyncMetadata.filter(Column("entity") == "all").fetchOne(db)
        }
        guard let meta else { return false }
        return Date().timeIntervalSince(meta.lastSyncAt) < staleCacheThreshold
    }

    // MARK: - Context Builders

    private func buildAIContext(nagId: UUID) async throws -> NagzAI.AIContext? {
        let nagIdString = nagId.uuidString
        let reader = await db.reader

        guard let nag = try await reader.read({ db in
            try CachedNag.filter(Column("id") == nagIdString).fetchOne(db)
        }) else {
            return nil
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

        let timeConflictCount = try await reader.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM cached_nag_events e
                JOIN cached_nags n ON e.nagId = n.id
                WHERE n.recipientId = ? AND n.familyId = ?
                AND e.eventType = 'excuse_submitted' AND e.at >= ?
                AND e.payload LIKE '%time_conflict%'
                """, arguments: [nag.recipientId, nag.familyId, sevenDaysAgo]) ?? 0
        }

        let catStats = try await reader.read { db -> (total: Int, completed: Int) in
            let total = try CachedNag
                .filter(Column("recipientId") == nag.recipientId)
                .filter(Column("familyId") == nag.familyId)
                .filter(Column("category") == nag.category)
                .filter(Column("id") != nagIdString)
                .fetchCount(db)
            let completed = try CachedNag
                .filter(Column("recipientId") == nag.recipientId)
                .filter(Column("familyId") == nag.familyId)
                .filter(Column("category") == nag.category)
                .filter(Column("id") != nagIdString)
                .filter(Column("status") == "completed")
                .fetchCount(db)
            return (total, completed)
        }

        let allStats = try await reader.read { db -> (total: Int, completed: Int) in
            let total = try CachedNag
                .filter(Column("recipientId") == nag.recipientId)
                .filter(Column("familyId") == nag.familyId)
                .filter(Column("id") != nagIdString)
                .fetchCount(db)
            let completed = try CachedNag
                .filter(Column("recipientId") == nag.recipientId)
                .filter(Column("familyId") == nag.familyId)
                .filter(Column("id") != nagIdString)
                .filter(Column("status") == "completed")
                .fetchCount(db)
            return (total, completed)
        }

        return NagzAI.AIContext(
            nagId: nagId,
            userId: UUID(uuidString: nag.recipientId)!,
            familyId: UUID(uuidString: nag.familyId)!,
            category: nag.category,
            status: nag.status,
            dueAt: nag.dueAt,
            missCount7D: missCount,
            streak: streak,
            timeConflictCount: timeConflictCount,
            categoryTotal: catStats.total,
            categoryCompleted: catStats.completed,
            overallTotal: allStats.total,
            overallCompleted: allStats.completed
        )
    }

    private func buildPatternsContext(userId: UUID, familyId: UUID) async throws -> NagzAI.PatternsContext {
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

        return NagzAI.PatternsContext(
            userId: userId,
            familyId: familyId,
            missedDates: dates
        )
    }

    private func buildDigestContext(familyId: UUID) async throws -> NagzAI.DigestContext? {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let familyIdString = familyId.uuidString
        let reader = await db.reader

        // Get distinct recipients in this family with recent nags
        let memberRows = try await reader.read { db -> [(userId: String, totalNags: Int, completed: Int, missed: Int)] in
            try Row.fetchAll(db, sql: """
                SELECT n.recipientId,
                       COUNT(*) AS totalNags,
                       SUM(CASE WHEN n.status = 'completed' THEN 1 ELSE 0 END) AS completed,
                       SUM(CASE WHEN n.status = 'missed' THEN 1 ELSE 0 END) AS missed
                FROM cached_nags n
                WHERE n.familyId = ? AND n.createdAt >= ?
                GROUP BY n.recipientId
                """, arguments: [familyIdString, sevenDaysAgo])
                .map { row in
                    (
                        userId: row["recipientId"] as String,
                        totalNags: row["totalNags"] as Int,
                        completed: row["completed"] as Int,
                        missed: row["missed"] as Int
                    )
                }
        }

        guard !memberRows.isEmpty else { return nil }

        let members = memberRows.map { row in
            NagzAI.DigestMemberInput(
                userId: UUID(uuidString: row.userId)!,
                displayName: nil,
                totalNags: row.totalNags,
                completed: row.completed,
                missed: row.missed
            )
        }

        return NagzAI.DigestContext(familyId: familyId, members: members)
    }

    // MARK: - Enum Bridging

    private func bridgeTone(_ tone: NagzAI.AITone) -> AITone {
        AITone(rawValue: tone.rawValue)!
    }

    private func bridgeExcuseCategory(_ category: NagzAI.ExcuseCategory) -> ExcuseCategory {
        ExcuseCategory(rawValue: category.rawValue)!
    }
}
