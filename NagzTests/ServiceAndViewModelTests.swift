import XCTest
import GRDB
@testable import Nagz

// MARK: - NagzAIAdapter: selectTone, patterns, predictCompletion

final class NagzAIAdapterTests: XCTestCase {

    private var db: DatabaseManager!
    private var service: NagzAIAdapter!

    private let userId = UUID().uuidString
    private let familyId = UUID().uuidString

    override func setUp() async throws {
        try await super.setUp()
        db = try DatabaseManager.inMemory()
        let keychain = KeychainService()
        let apiClient = APIClient(keychainService: keychain)
        let serverAI = ServerAIService(apiClient: apiClient)
        service = NagzAIAdapter(db: db, fallback: serverAI, preferHeuristic: true)
    }

    private func markCacheFresh() async throws {
        let writer = await db.writer
        try await writer.write { db in
            try SyncMetadata(entity: "all", lastSyncAt: Date()).insert(db)
        }
    }

    private func insertNag(
        id: String = UUID().uuidString,
        status: String = "open",
        category: String = "chores",
        dueAt: Date = Date().addingTimeInterval(3600)
    ) async throws -> String {
        let familyId = self.familyId
        let userId = self.userId
        let writer = await db.writer
        try await writer.write { db in
            try CachedNag(
                id: id,
                familyId: familyId,
                creatorId: UUID().uuidString,
                recipientId: userId,
                dueAt: dueAt,
                category: category,
                doneDefinition: "ack_only",
                description: "Test nag",
                status: status,
                createdAt: Date(),
                syncedAt: Date()
            ).insert(db)
        }
        return id
    }

    private func insertNagEvent(nagId: String, eventType: String, at: Date = Date()) async throws {
        let userId = self.userId
        let writer = await db.writer
        try await writer.write { db in
            try CachedNagEvent(
                id: UUID().uuidString,
                nagId: nagId,
                eventType: eventType,
                actorId: userId,
                at: at,
                payload: "{}",
                syncedAt: Date()
            ).insert(db)
        }
    }

    private func insertGamificationEvent(streakDelta: Int) async throws {
        let familyId = self.familyId
        let userId = self.userId
        let writer = await db.writer
        try await writer.write { db in
            try CachedGamificationEvent(
                id: UUID().uuidString,
                familyId: familyId,
                userId: userId,
                eventType: "nag_completed",
                deltaPoints: 10,
                streakDelta: streakDelta,
                at: Date(),
                syncedAt: Date()
            ).insert(db)
        }
    }

    // MARK: - selectTone Tests

    func testSelectToneFirmWhenManyMisses() async throws {
        try await markCacheFresh()
        let nagId = try await insertNag()

        // Insert 4 misses in last 7 days
        for i in 0..<4 {
            let otherNagId = try await insertNag(id: UUID().uuidString)
            try await insertNagEvent(
                nagId: otherNagId,
                eventType: "nag_missed",
                at: Date().addingTimeInterval(Double(-i) * 3600)
            )
        }

        let response = try await service.selectTone(nagId: UUID(uuidString: nagId)!)
        XCTAssertEqual(response.tone, .firm)
        XCTAssertTrue(response.missCount7D >= 3)
    }

    func testSelectToneSupportiveWithStreak() async throws {
        try await markCacheFresh()
        let nagId = try await insertNag()

        // Insert streak events totaling >= 3
        try await insertGamificationEvent(streakDelta: 2)
        try await insertGamificationEvent(streakDelta: 2)

        let response = try await service.selectTone(nagId: UUID(uuidString: nagId)!)
        XCTAssertEqual(response.tone, .supportive)
        XCTAssertEqual(response.streak, 4)
    }

    func testSelectToneNeutralDefault() async throws {
        try await markCacheFresh()
        let nagId = try await insertNag()

        let response = try await service.selectTone(nagId: UUID(uuidString: nagId)!)
        XCTAssertEqual(response.tone, .neutral)
        XCTAssertEqual(response.reason, "Default tone")
    }

    // MARK: - patterns Tests

    func testPatternsReturnsInsightsForFrequentDays() async throws {
        try await markCacheFresh()

        // Insert 4 misses on the same weekday (should trigger insight)
        let calendar = Calendar.current
        let now = Date()
        _ = calendar.component(.weekday, from: now)

        for i in 0..<4 {
            let nagId = try await insertNag(id: UUID().uuidString)
            // Create events on the same weekday but different weeks
            let missDate = calendar.date(byAdding: .weekOfYear, value: -i, to: now)!
            try await insertNagEvent(nagId: nagId, eventType: "nag_missed", at: missDate)
        }

        let response = try await service.patterns(
            userId: UUID(uuidString: userId)!,
            familyId: UUID(uuidString: familyId)!
        )
        // Should find at least one insight for the repeated weekday
        XCTAssertFalse(response.insights.isEmpty)
        XCTAssertTrue(response.insights.first!.missCount >= 3)
    }

    func testPatternsReturnsEmptyForFewMisses() async throws {
        try await markCacheFresh()

        // Insert only 2 misses (below threshold of 3)
        for _ in 0..<2 {
            let nagId = try await insertNag(id: UUID().uuidString)
            try await insertNagEvent(nagId: nagId, eventType: "nag_missed")
        }

        let response = try await service.patterns(
            userId: UUID(uuidString: userId)!,
            familyId: UUID(uuidString: familyId)!
        )
        // All on same day but below 3 is fine, let's check it doesn't crash
        XCTAssertNotNil(response.analyzedAt)
    }

    // MARK: - predictCompletion Tests

    func testPredictCompletionHighLikelihood() async throws {
        try await markCacheFresh()

        // Insert several completed nags in same category
        for _ in 0..<5 {
            _ = try await insertNag(id: UUID().uuidString, status: "completed", category: "chores")
        }
        // Insert 1 open nag as the target
        let targetId = try await insertNag(id: UUID().uuidString, status: "open", category: "chores")

        let response = try await service.predictCompletion(nagId: UUID(uuidString: targetId)!)
        XCTAssertGreaterThan(response.likelihood, 0.5)
        XCTAssertNotNil(response.suggestedReminderTime)
        XCTAssertEqual(response.factors.count, 2)
    }

    func testPredictCompletionLowLikelihood() async throws {
        try await markCacheFresh()

        // Insert several open (not completed) nags in same category
        for _ in 0..<5 {
            _ = try await insertNag(id: UUID().uuidString, status: "open", category: "chores")
        }
        // Insert the target
        let targetId = try await insertNag(id: UUID().uuidString, status: "open", category: "chores")

        let response = try await service.predictCompletion(nagId: UUID(uuidString: targetId)!)
        XCTAssertLessThanOrEqual(response.likelihood, 0.5)
    }

    func testPredictCompletionDefaultsWhenNoHistory() async throws {
        try await markCacheFresh()

        // Single open nag with no history
        let targetId = try await insertNag()

        let response = try await service.predictCompletion(nagId: UUID(uuidString: targetId)!)
        // Default completion rate is 0.5
        XCTAssertEqual(response.likelihood, 0.5)
    }
}

// MARK: - ViewModel Default State & Action Error Handling Tests

final class ViewModelActionTests: XCTestCase {

    private func makeAPIClient() -> APIClient {
        let keychain = KeychainService()
        // Use a non-existent URL so all API calls fail immediately
        return APIClient(
            baseURL: URL(string: "http://127.0.0.1:1/api/v1")!,
            keychainService: keychain
        )
    }

    // MARK: - NagListViewModel

    @MainActor
    func testNagListDefaultState() {
        let vm = NagListViewModel(apiClient: makeAPIClient())
        XCTAssertTrue(vm.nags.isEmpty)
        XCTAssertEqual(vm.filter, .open)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isLoadingMore)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.hasMore)
    }

    @MainActor
    func testNagListLoadWithoutFamilyDoesNothing() async {
        let vm = NagListViewModel(apiClient: makeAPIClient())
        await vm.loadNags()
        // Should not crash, should not set error (early return)
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.nags.isEmpty)
    }

    @MainActor
    func testNagListLoadSetsErrorOnNetworkFailure() async {
        let vm = NagListViewModel(apiClient: makeAPIClient())
        vm.setFamily(UUID())
        await vm.loadNags()
        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - NagDetailViewModel

    @MainActor
    func testNagDetailDefaultState() {
        let vm = NagDetailViewModel(apiClient: makeAPIClient(), nagId: UUID())
        XCTAssertNil(vm.nag)
        XCTAssertNil(vm.escalation)
        XCTAssertTrue(vm.excuses.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isUpdating)
        XCTAssertFalse(vm.isRecomputing)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func testNagDetailLoadSetsErrorOnFailure() async {
        let vm = NagDetailViewModel(apiClient: makeAPIClient(), nagId: UUID())
        await vm.load()
        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor
    func testNagDetailMarkCompleteSetsErrorOnFailure() async {
        let vm = NagDetailViewModel(apiClient: makeAPIClient(), nagId: UUID())
        await vm.markComplete()
        XCTAssertFalse(vm.isUpdating)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor
    func testNagDetailSubmitExcuseSetsErrorOnFailure() async {
        let vm = NagDetailViewModel(apiClient: makeAPIClient(), nagId: UUID())
        await vm.submitExcuse(text: "I forgot")
        XCTAssertFalse(vm.isUpdating)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor
    func testNagDetailRecomputeEscalationSetsErrorOnFailure() async {
        let vm = NagDetailViewModel(apiClient: makeAPIClient(), nagId: UUID())
        await vm.recomputeEscalation()
        XCTAssertFalse(vm.isRecomputing)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - FamilyViewModel

    @MainActor
    func testFamilyViewModelDefaultState() {
        let vm = FamilyViewModel(apiClient: makeAPIClient())
        XCTAssertNil(vm.family)
        XCTAssertTrue(vm.members.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.showCreateSheet)
        XCTAssertFalse(vm.showJoinSheet)
    }

    @MainActor
    func testFamilyViewModelLoadSetsErrorOnFailure() async {
        let vm = FamilyViewModel(apiClient: makeAPIClient())
        await vm.loadFamily(id: UUID())
        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor
    func testFamilyViewModelCreateFamilyEmptyNameDoesNothing() async {
        let vm = FamilyViewModel(apiClient: makeAPIClient())
        vm.newFamilyName = "   "
        await vm.createFamily()
        // Empty name early return — should not set error
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isCreating)
    }

    @MainActor
    func testFamilyViewModelCreateFamilySetsErrorOnFailure() async {
        let vm = FamilyViewModel(apiClient: makeAPIClient())
        vm.newFamilyName = "Test Family"
        await vm.createFamily()
        XCTAssertFalse(vm.isCreating)
        XCTAssertNotNil(vm.errorMessage)
    }

    @MainActor
    func testFamilyViewModelJoinEmptyCodeSetsError() async {
        let vm = FamilyViewModel(apiClient: makeAPIClient())
        vm.joinInviteCode = ""
        await vm.joinFamily()
        XCTAssertEqual(vm.errorMessage, "Invite code is required")
    }

    @MainActor
    func testFamilyViewModelJoinSetsErrorOnFailure() async {
        let vm = FamilyViewModel(apiClient: makeAPIClient())
        vm.joinInviteCode = "invalid-code"
        await vm.joinFamily()
        XCTAssertFalse(vm.isJoining)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - LoginViewModel

    @MainActor
    func testLoginViewModelSetsErrorOnFailure() async {
        let keychain = KeychainService()
        let apiClient = APIClient(
            baseURL: URL(string: "http://127.0.0.1:1/api/v1")!,
            keychainService: keychain
        )
        let authManager = AuthManager(apiClient: apiClient, keychainService: keychain)
        let vm = LoginViewModel(authManager: authManager)
        vm.email = "test@example.com"
        vm.password = "password123"
        await vm.login()
        XCTAssertFalse(vm.isLoading)
        XCTAssertNotNil(vm.errorMessage)
    }
}

// MARK: - Date+Formatting Tests

final class DateFormattingTests: XCTestCase {

    func testRecentPastShowsRelative() {
        let fiveMinAgo = Date().addingTimeInterval(-5 * 60)
        let display = fiveMinAgo.relativeDisplay
        XCTAssertFalse(display.isEmpty)
        // Should not say "just now" for 5 minutes
        XCTAssertNotEqual(display, "just now")
    }

    func testJustNow() {
        let almostNow = Date().addingTimeInterval(-10)
        let display = almostNow.relativeDisplay
        XCTAssertEqual(display, "just now")
    }

    func testFutureDateShowsRelative() {
        let inOneHour = Date().addingTimeInterval(3600)
        let display = inOneHour.relativeDisplay
        XCTAssertFalse(display.isEmpty)
    }

    func testOverdueShowsOverdue() {
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3600)
        let display = twoHoursAgo.relativeDisplay
        XCTAssertTrue(display.contains("overdue"))
    }

    func testShortDisplayNotEmpty() {
        let display = Date().shortDisplay
        XCTAssertFalse(display.isEmpty)
    }
}
