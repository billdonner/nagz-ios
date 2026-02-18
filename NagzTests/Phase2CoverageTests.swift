import XCTest
import GRDB
@testable import Nagz

// MARK: - AI Models Decoding Tests

final class AIModelsDecodingTests: XCTestCase {

    private var decoder: JSONDecoder!

    override func setUp() {
        super.setUp()
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: dateString) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(dateString)")
        }
    }

    // MARK: - ExcuseSummaryResponse

    func testExcuseSummaryResponseDecoding() throws {
        let json = """
        {
            "nag_id": "550e8400-e29b-41d4-a716-446655440001",
            "summary": "I forgot to do it",
            "category": "forgot",
            "confidence": 0.7
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ExcuseSummaryResponse.self, from: json)
        XCTAssertEqual(response.nagId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001"))
        XCTAssertEqual(response.summary, "I forgot to do it")
        XCTAssertEqual(response.category, .forgot)
        XCTAssertEqual(response.confidence, 0.7)
    }

    func testAllExcuseCategories() {
        XCTAssertEqual(ExcuseCategory.forgot.rawValue, "forgot")
        XCTAssertEqual(ExcuseCategory.timeConflict.rawValue, "time_conflict")
        XCTAssertEqual(ExcuseCategory.unclearInstructions.rawValue, "unclear_instructions")
        XCTAssertEqual(ExcuseCategory.lackingResources.rawValue, "lacking_resources")
        XCTAssertEqual(ExcuseCategory.refused.rawValue, "refused")
        XCTAssertEqual(ExcuseCategory.other.rawValue, "other")
    }

    // MARK: - ToneSelectResponse

    func testToneSelectResponseDecoding() throws {
        // convertFromSnakeCase turns "miss_count_7d" into "missCount7D" (capital D),
        // so we must use a plain decoder with the exact key "missCount7d".
        let plainDecoder = JSONDecoder()
        plainDecoder.dateDecodingStrategy = decoder.dateDecodingStrategy
        let json = """
        {
            "nagId": "550e8400-e29b-41d4-a716-446655440002",
            "tone": "firm",
            "missCount7d": 5,
            "streak": 0,
            "reason": "5 misses in last 7 days"
        }
        """.data(using: .utf8)!

        let response = try plainDecoder.decode(ToneSelectResponse.self, from: json)
        XCTAssertEqual(response.tone, .firm)
        XCTAssertEqual(response.missCount7d, 5)
        XCTAssertEqual(response.streak, 0)
        XCTAssertEqual(response.reason, "5 misses in last 7 days")
    }

    func testAllAITones() {
        XCTAssertEqual(AITone.neutral.rawValue, "neutral")
        XCTAssertEqual(AITone.supportive.rawValue, "supportive")
        XCTAssertEqual(AITone.firm.rawValue, "firm")
    }

    // MARK: - CoachingResponse

    func testCoachingResponseDecoding() throws {
        let json = """
        {
            "nag_id": "550e8400-e29b-41d4-a716-446655440003",
            "tip": "Stay on track!",
            "category": "motivation",
            "scenario": "streak_3"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(CoachingResponse.self, from: json)
        XCTAssertEqual(response.tip, "Stay on track!")
        XCTAssertEqual(response.category, "motivation")
        XCTAssertEqual(response.scenario, "streak_3")
    }

    // MARK: - PatternsResponse

    func testPatternsResponseDecoding() throws {
        let json = """
        {
            "user_id": "550e8400-e29b-41d4-a716-446655440004",
            "family_id": "550e8400-e29b-41d4-a716-446655440005",
            "insights": [
                {"day_of_week": "Monday", "miss_count": 5}
            ],
            "analyzed_at": "2026-02-18T10:00:00+00:00"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(PatternsResponse.self, from: json)
        XCTAssertEqual(response.insights.count, 1)
        XCTAssertEqual(response.insights[0].dayOfWeek, "Monday")
        XCTAssertEqual(response.insights[0].missCount, 5)
    }

    func testPatternsResponseEmptyInsights() throws {
        let json = """
        {
            "user_id": "550e8400-e29b-41d4-a716-446655440004",
            "family_id": "550e8400-e29b-41d4-a716-446655440005",
            "insights": [],
            "analyzed_at": "2026-02-18T10:00:00+00:00"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(PatternsResponse.self, from: json)
        XCTAssertTrue(response.insights.isEmpty)
    }

    // MARK: - DigestResponse

    func testDigestResponseDecoding() throws {
        let json = """
        {
            "family_id": "550e8400-e29b-41d4-a716-446655440006",
            "period_start": "2026-02-11T00:00:00+00:00",
            "period_end": "2026-02-18T00:00:00+00:00",
            "summary_text": "Great week overall!",
            "member_summaries": [
                {
                    "user_id": "550e8400-e29b-41d4-a716-446655440007",
                    "display_name": "Alice",
                    "total_nags": 5,
                    "completed": 4,
                    "missed": 1,
                    "completion_rate": 0.8
                }
            ],
            "totals": {
                "total_nags": 5,
                "completed": 4,
                "missed": 1,
                "open": 0,
                "completion_rate": 0.8
            }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(DigestResponse.self, from: json)
        XCTAssertEqual(response.summaryText, "Great week overall!")
        XCTAssertEqual(response.memberSummaries.count, 1)
        XCTAssertEqual(response.memberSummaries[0].displayName, "Alice")
        XCTAssertEqual(response.totals.totalNags, 5)
        XCTAssertEqual(response.totals.completionRate, 0.8)
    }

    // MARK: - PredictCompletionResponse

    func testPredictCompletionResponseDecoding() throws {
        let json = """
        {
            "nag_id": "550e8400-e29b-41d4-a716-446655440008",
            "likelihood": 0.75,
            "suggested_reminder_time": "2026-02-18T09:30:00+00:00",
            "factors": [
                {"name": "category_rate", "value": 0.8},
                {"name": "overall_rate", "value": 0.7}
            ]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(PredictCompletionResponse.self, from: json)
        XCTAssertEqual(response.likelihood, 0.75)
        XCTAssertNotNil(response.suggestedReminderTime)
        XCTAssertEqual(response.factors.count, 2)
        XCTAssertEqual(response.factors[0].name, "category_rate")
    }

    func testPredictCompletionNullReminder() throws {
        let json = """
        {
            "nag_id": "550e8400-e29b-41d4-a716-446655440008",
            "likelihood": 0.5,
            "suggested_reminder_time": null,
            "factors": []
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(PredictCompletionResponse.self, from: json)
        XCTAssertNil(response.suggestedReminderTime)
        XCTAssertTrue(response.factors.isEmpty)
    }

    // MARK: - PushBackResponse

    func testPushBackResponseDenied() throws {
        let json = """
        {
            "nag_id": "550e8400-e29b-41d4-a716-446655440009",
            "should_push_back": false,
            "message": null,
            "tone": null,
            "reason": "Pushback mode is off"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(PushBackResponse.self, from: json)
        XCTAssertFalse(response.shouldPushBack)
        XCTAssertNil(response.message)
        XCTAssertNil(response.tone)
        XCTAssertEqual(response.reason, "Pushback mode is off")
    }

    func testPushBackResponseApproved() throws {
        let json = """
        {
            "nag_id": "550e8400-e29b-41d4-a716-446655440009",
            "should_push_back": true,
            "message": "Just a reminder about your pending task.",
            "tone": "neutral",
            "reason": "Pushback #1 sent with neutral tone"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(PushBackResponse.self, from: json)
        XCTAssertTrue(response.shouldPushBack)
        XCTAssertEqual(response.message, "Just a reminder about your pending task.")
        XCTAssertEqual(response.tone, .neutral)
    }

    // MARK: - SyncResponse

    func testSyncResponseDecoding() throws {
        let json = """
        {
            "nags": [{
                "id": "550e8400-e29b-41d4-a716-446655440010",
                "family_id": "550e8400-e29b-41d4-a716-446655440011",
                "creator_id": "550e8400-e29b-41d4-a716-446655440012",
                "recipient_id": "550e8400-e29b-41d4-a716-446655440013",
                "due_at": "2026-02-20T10:00:00+00:00",
                "category": "chores",
                "done_definition": "ack_only",
                "description": "Clean room",
                "status": "open",
                "created_at": "2026-02-18T10:00:00+00:00"
            }],
            "nag_events": [],
            "ai_mediation_events": [],
            "gamification_events": [],
            "server_time": "2026-02-18T10:00:00+00:00"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(SyncResponse.self, from: json)
        XCTAssertEqual(response.nags.count, 1)
        XCTAssertEqual(response.nags[0].category, "chores")
        XCTAssertEqual(response.nags[0].description, "Clean room")
        XCTAssertTrue(response.nagEvents.isEmpty)
        XCTAssertTrue(response.aiMediationEvents.isEmpty)
        XCTAssertTrue(response.gamificationEvents.isEmpty)
    }

    func testSyncResponseEmpty() throws {
        let json = """
        {
            "nags": [],
            "nag_events": [],
            "ai_mediation_events": [],
            "gamification_events": [],
            "server_time": "2026-02-18T10:00:00+00:00"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(SyncResponse.self, from: json)
        XCTAssertTrue(response.nags.isEmpty)
    }
}

// MARK: - DatabaseManager Tests

final class DatabaseManagerTests: XCTestCase {

    func testInMemoryCreation() throws {
        let db = try DatabaseManager.inMemory()
        // If we get here, migrations ran successfully
        XCTAssertNotNil(db)
    }

    func testWriteAndReadNag() async throws {
        let db = try DatabaseManager.inMemory()
        let writer = await db.writer
        let reader = await db.reader

        let nag = CachedNag(
            id: UUID().uuidString,
            familyId: UUID().uuidString,
            creatorId: UUID().uuidString,
            recipientId: UUID().uuidString,
            dueAt: Date(),
            category: "chores",
            doneDefinition: "ack_only",
            description: "Test nag",
            status: "open",
            createdAt: Date(),
            syncedAt: Date()
        )

        try await writer.write { db in
            try nag.save(db)
        }

        let fetched = try await reader.read { db in
            try CachedNag.fetchAll(db)
        }

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, nag.id)
        XCTAssertEqual(fetched[0].category, "chores")
        XCTAssertEqual(fetched[0].description, "Test nag")
    }

    func testWriteAndReadNagEvent() async throws {
        let db = try DatabaseManager.inMemory()
        let writer = await db.writer

        let event = CachedNagEvent(
            id: UUID().uuidString,
            nagId: UUID().uuidString,
            eventType: "nag_missed",
            actorId: UUID().uuidString,
            at: Date(),
            payload: "{}",
            syncedAt: Date()
        )

        try await writer.write { db in
            try event.save(db)
        }

        let reader = await db.reader
        let count = try await reader.read { db in
            try CachedNagEvent.fetchCount(db)
        }
        XCTAssertEqual(count, 1)
    }

    func testWriteAndReadGamificationEvent() async throws {
        let db = try DatabaseManager.inMemory()
        let writer = await db.writer

        let event = CachedGamificationEvent(
            id: UUID().uuidString,
            familyId: UUID().uuidString,
            userId: UUID().uuidString,
            eventType: "nag_completed",
            deltaPoints: 10,
            streakDelta: 1,
            at: Date(),
            syncedAt: Date()
        )

        try await writer.write { db in
            try event.save(db)
        }

        let reader = await db.reader
        let fetched = try await reader.read { db in
            try CachedGamificationEvent.fetchAll(db)
        }
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].deltaPoints, 10)
        XCTAssertEqual(fetched[0].streakDelta, 1)
    }

    func testWriteAndReadSyncMetadata() async throws {
        let db = try DatabaseManager.inMemory()
        let writer = await db.writer

        let now = Date()
        let meta = SyncMetadata(entity: "all", lastSyncAt: now)

        try await writer.write { db in
            try meta.save(db)
        }

        let reader = await db.reader
        let fetched = try await reader.read { db in
            try SyncMetadata.filter(Column("entity") == "all").fetchOne(db)
        }

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.entity, "all")
    }

    func testWriteAndReadAIMediationEvent() async throws {
        let db = try DatabaseManager.inMemory()
        let writer = await db.writer

        let event = CachedAIMediationEvent(
            id: UUID().uuidString,
            nagId: UUID().uuidString,
            promptType: "excuse",
            tone: "neutral",
            summary: "Test summary",
            at: Date(),
            syncedAt: Date()
        )

        try await writer.write { db in
            try event.save(db)
        }

        let reader = await db.reader
        let fetched = try await reader.read { db in
            try CachedAIMediationEvent.fetchAll(db)
        }
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].promptType, "excuse")
        XCTAssertEqual(fetched[0].tone, "neutral")
    }

    func testWriteAndReadPreferences() async throws {
        let db = try DatabaseManager.inMemory()
        let writer = await db.writer

        let prefs = CachedPreferences(
            userId: UUID().uuidString,
            familyId: UUID().uuidString,
            prefsJson: "{\"tone\":\"friendly\"}",
            syncedAt: Date()
        )

        try await writer.write { db in
            try prefs.save(db)
        }

        let reader = await db.reader
        let fetched = try await reader.read { db in
            try CachedPreferences.fetchAll(db)
        }
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched[0].prefsJson.contains("friendly"))
    }

    func testClearAll() async throws {
        let db = try DatabaseManager.inMemory()
        let writer = await db.writer

        // Write some data
        try await writer.write { db in
            try CachedNag(
                id: UUID().uuidString, familyId: UUID().uuidString,
                creatorId: UUID().uuidString, recipientId: UUID().uuidString,
                dueAt: Date(), category: "chores", doneDefinition: "ack_only",
                description: nil, status: "open", createdAt: Date(), syncedAt: Date()
            ).save(db)

            try SyncMetadata(entity: "all", lastSyncAt: Date()).save(db)
        }

        // Clear everything
        try await db.clearAll()

        let reader = await db.reader
        let nagCount = try await reader.read { db in try CachedNag.fetchCount(db) }
        let metaCount = try await reader.read { db in try SyncMetadata.fetchCount(db) }

        XCTAssertEqual(nagCount, 0)
        XCTAssertEqual(metaCount, 0)
    }

    func testPruneStaleData() async throws {
        let db = try DatabaseManager.inMemory()
        let writer = await db.writer

        let oldDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let recentDate = Date()

        // Write old event (should be pruned) and recent event (should remain)
        try await writer.write { db in
            try CachedNagEvent(
                id: UUID().uuidString, nagId: UUID().uuidString,
                eventType: "nag_missed", actorId: UUID().uuidString,
                at: oldDate, payload: "{}", syncedAt: oldDate
            ).save(db)

            try CachedNagEvent(
                id: UUID().uuidString, nagId: UUID().uuidString,
                eventType: "nag_missed", actorId: UUID().uuidString,
                at: recentDate, payload: "{}", syncedAt: recentDate
            ).save(db)
        }

        try await db.pruneStaleData()

        let reader = await db.reader
        let count = try await reader.read { db in try CachedNagEvent.fetchCount(db) }
        XCTAssertEqual(count, 1) // Only recent event remains
    }

    func testUpsertNag() async throws {
        let db = try DatabaseManager.inMemory()
        let writer = await db.writer
        let nagId = UUID().uuidString

        let nag = CachedNag(
            id: nagId, familyId: UUID().uuidString,
            creatorId: UUID().uuidString, recipientId: UUID().uuidString,
            dueAt: Date(), category: "chores", doneDefinition: "ack_only",
            description: nil, status: "open", createdAt: Date(), syncedAt: Date()
        )

        // Insert
        try await writer.write { db in try nag.save(db) }

        // Update via upsert (same id, different status)
        let updatedNag = CachedNag(
            id: nagId, familyId: nag.familyId,
            creatorId: nag.creatorId, recipientId: nag.recipientId,
            dueAt: nag.dueAt, category: nag.category, doneDefinition: nag.doneDefinition,
            description: nag.description, status: "completed",
            createdAt: nag.createdAt, syncedAt: nag.syncedAt
        )
        try await writer.write { db in try updatedNag.save(db) }

        let reader = await db.reader
        let fetched = try await reader.read { db in
            try CachedNag.filter(Column("id") == nagId).fetchOne(db)
        }
        XCTAssertEqual(fetched?.status, "completed")

        let totalCount = try await reader.read { db in try CachedNag.fetchCount(db) }
        XCTAssertEqual(totalCount, 1) // No duplicate
    }
}

// MARK: - OnDeviceAIService Heuristic Tests

final class OnDeviceAIHeuristicTests: XCTestCase {

    private func makeService() throws -> (OnDeviceAIService, DatabaseManager) {
        let db = try DatabaseManager.inMemory()
        let keychain = KeychainService()
        let apiClient = APIClient(keychainService: keychain)
        let serverAI = ServerAIService(apiClient: apiClient)
        let onDevice = OnDeviceAIService(db: db, fallback: serverAI)
        return (onDevice, db)
    }

    // MARK: - Excuse Summarization (runs entirely locally)

    func testSummarizeExcuseForgot() async throws {
        let (service, _) = try makeService()
        let response = try await service.summarizeExcuse("I forgot to do my chores", nagId: UUID())
        XCTAssertEqual(response.category, .forgot)
        XCTAssertEqual(response.confidence, 0.7)
    }

    func testSummarizeExcuseTimeConflict() async throws {
        let (service, _) = try makeService()
        let response = try await service.summarizeExcuse("I was too busy with my schedule", nagId: UUID())
        XCTAssertEqual(response.category, .timeConflict)
    }

    func testSummarizeExcuseUnclear() async throws {
        let (service, _) = try makeService()
        let response = try await service.summarizeExcuse("I was confused about what to do", nagId: UUID())
        XCTAssertEqual(response.category, .unclearInstructions)
    }

    func testSummarizeExcuseLacking() async throws {
        let (service, _) = try makeService()
        let response = try await service.summarizeExcuse("I don't have the supplies I need", nagId: UUID())
        XCTAssertEqual(response.category, .lackingResources)
    }

    func testSummarizeExcuseRefused() async throws {
        let (service, _) = try makeService()
        let response = try await service.summarizeExcuse("I won't do this task", nagId: UUID())
        XCTAssertEqual(response.category, .refused)
    }

    func testSummarizeExcuseOther() async throws {
        let (service, _) = try makeService()
        let response = try await service.summarizeExcuse("xyz abc 123", nagId: UUID())
        XCTAssertEqual(response.category, .other)
        XCTAssertEqual(response.confidence, 0.3)
    }

    func testSummarizeExcuseTruncation() async throws {
        let (service, _) = try makeService()
        let longText = String(repeating: "A", count: 500)
        let response = try await service.summarizeExcuse(longText, nagId: UUID())
        XCTAssertEqual(response.summary.count, 200)
    }

    func testSummarizeExcusePreservesNagId() async throws {
        let (service, _) = try makeService()
        let nagId = UUID()
        let response = try await service.summarizeExcuse("test", nagId: nagId)
        XCTAssertEqual(response.nagId, nagId)
    }

    // MARK: - Coaching (runs entirely locally)

    func testCoachingReturnsValidResponse() async throws {
        let (service, _) = try makeService()
        let nagId = UUID()
        let response = try await service.coaching(nagId: nagId)
        XCTAssertEqual(response.nagId, nagId)
        XCTAssertFalse(response.tip.isEmpty)
        XCTAssertFalse(response.category.isEmpty)
        XCTAssertFalse(response.scenario.isEmpty)
    }
}

// MARK: - APIEndpoint AI Factory Tests

final class APIEndpointAITests: XCTestCase {

    func testAISummarizeExcuseEndpoint() {
        let nagId = UUID()
        let endpoint = APIEndpoint.aiSummarizeExcuse(text: "I forgot", nagId: nagId)
        XCTAssertEqual(endpoint.path, "/ai/summarize-excuse")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertTrue(endpoint.requiresAuth)
        XCTAssertNotNil(endpoint.body)
    }

    func testAISelectToneEndpoint() {
        let nagId = UUID()
        let endpoint = APIEndpoint.aiSelectTone(nagId: nagId)
        XCTAssertEqual(endpoint.path, "/ai/select-tone")
        XCTAssertEqual(endpoint.method, .post)
    }

    func testAICoachingEndpoint() {
        let endpoint = APIEndpoint.aiCoaching(nagId: UUID())
        XCTAssertEqual(endpoint.path, "/ai/coaching")
        XCTAssertEqual(endpoint.method, .post)
    }

    func testAIPatternsEndpoint() {
        let userId = UUID()
        let familyId = UUID()
        let endpoint = APIEndpoint.aiPatterns(userId: userId, familyId: familyId)
        XCTAssertEqual(endpoint.path, "/ai/patterns")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.queryItems.count, 2)
    }

    func testAIDigestEndpoint() {
        let familyId = UUID()
        let endpoint = APIEndpoint.aiDigest(familyId: familyId)
        XCTAssertEqual(endpoint.path, "/ai/digest")
        XCTAssertEqual(endpoint.queryItems.count, 1)
    }

    func testAIPredictCompletionEndpoint() {
        let endpoint = APIEndpoint.aiPredictCompletion(nagId: UUID())
        XCTAssertEqual(endpoint.path, "/ai/predict-completion")
        XCTAssertEqual(endpoint.method, .get)
    }

    func testAIPushBackEndpoint() {
        let endpoint = APIEndpoint.aiPushBack(nagId: UUID())
        XCTAssertEqual(endpoint.path, "/ai/push-back")
        XCTAssertEqual(endpoint.method, .post)
    }

    func testSyncEventsEndpoint() {
        let familyId = UUID()
        let endpoint = APIEndpoint.syncEvents(familyId: familyId, since: nil)
        XCTAssertEqual(endpoint.path, "/sync/events")
        XCTAssertEqual(endpoint.queryItems.count, 1)
    }

    func testSyncEventsEndpointWithSince() {
        let familyId = UUID()
        let since = Date()
        let endpoint = APIEndpoint.syncEvents(familyId: familyId, since: since)
        XCTAssertEqual(endpoint.queryItems.count, 2)
    }
}
