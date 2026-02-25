import XCTest
@testable import Nagz

final class ModelDecodingTests: XCTestCase {

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

    func testAuthResponseDecoding() throws {
        let json = """
        {
            "access_token": "eyJhbGciOiJIUzI1NiJ9.test",
            "refresh_token": "eyJhbGciOiJIUzI1NiJ9.refresh",
            "token_type": "bearer",
            "user": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "email": "test@example.com",
                "display_name": "Test User",
                "status": "active",
                "created_at": "2026-02-16T14:12:00+00:00"
            }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(AuthResponse.self, from: json)
        XCTAssertEqual(response.accessToken, "eyJhbGciOiJIUzI1NiJ9.test")
        XCTAssertEqual(response.user.email, "test@example.com")
        XCTAssertEqual(response.user.displayName, "Test User")
        XCTAssertEqual(response.user.id, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000"))
    }

    func testNagResponseDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "family_id": "550e8400-e29b-41d4-a716-446655440002",
            "creator_id": "550e8400-e29b-41d4-a716-446655440003",
            "recipient_id": "550e8400-e29b-41d4-a716-446655440004",
            "due_at": "2026-02-17T10:00:00+00:00",
            "category": "homework",
            "done_definition": "ack_only",
            "description": "Finish math worksheet",
            "strategy_template": "friendly_reminder",
            "status": "open",
            "created_at": "2026-02-16T14:12:00+00:00"
        }
        """.data(using: .utf8)!

        let nag = try decoder.decode(NagResponse.self, from: json)
        XCTAssertEqual(nag.category, .homework)
        XCTAssertEqual(nag.doneDefinition, .ackOnly)
        XCTAssertEqual(nag.status, .open)
        XCTAssertEqual(nag.description, "Finish math worksheet")
        XCTAssertEqual(nag.strategyTemplate, .friendlyReminder)
    }

    func testFamilyResponseDecoding() throws {
        let json = """
        {
            "family_id": "550e8400-e29b-41d4-a716-446655440010",
            "name": "The Smiths",
            "invite_code": "ABC123",
            "created_at": "2026-02-16T14:12:00+00:00"
        }
        """.data(using: .utf8)!

        let family = try decoder.decode(FamilyResponse.self, from: json)
        XCTAssertEqual(family.name, "The Smiths")
        XCTAssertEqual(family.id, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440010"))
    }

    func testMemberDetailDecoding() throws {
        let json = """
        {
            "user_id": "550e8400-e29b-41d4-a716-446655440020",
            "display_name": "Alice",
            "family_id": "550e8400-e29b-41d4-a716-446655440021",
            "role": "guardian",
            "status": "active",
            "joined_at": "2026-02-16T14:12:00+00:00"
        }
        """.data(using: .utf8)!

        let member = try decoder.decode(MemberDetail.self, from: json)
        XCTAssertEqual(member.displayName, "Alice")
        XCTAssertEqual(member.role, .guardian)
        XCTAssertEqual(member.status, .active)
    }

    func testEscalationResponseDecoding() throws {
        let json = """
        {
            "nag_id": "550e8400-e29b-41d4-a716-446655440030",
            "current_phase": "phase_1_due_soon",
            "due_at": "2026-02-17T10:00:00+00:00",
            "computed_at": "2026-02-16T14:12:00+00:00"
        }
        """.data(using: .utf8)!

        let escalation = try decoder.decode(EscalationResponse.self, from: json)
        XCTAssertEqual(escalation.currentPhase, .phase1DueSoon)
        XCTAssertEqual(escalation.currentPhase.displayName, "Due Soon")
    }

    func testPaginatedResponseDecoding() throws {
        let json = """
        {
            "items": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440040",
                    "family_id": "550e8400-e29b-41d4-a716-446655440041",
                    "creator_id": "550e8400-e29b-41d4-a716-446655440042",
                    "recipient_id": "550e8400-e29b-41d4-a716-446655440043",
                    "due_at": "2026-02-17T10:00:00+00:00",
                    "category": "chores",
                    "done_definition": "binary_check",
                    "description": null,
                    "strategy_template": "friendly_reminder",
                    "status": "open",
                    "created_at": "2026-02-16T14:12:00+00:00"
                }
            ],
            "total": 25,
            "limit": 50,
            "offset": 0
        }
        """.data(using: .utf8)!

        let page = try decoder.decode(PaginatedResponse<NagResponse>.self, from: json)
        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.total, 25)
        XCTAssertFalse(page.hasMore)
        XCTAssertEqual(page.items[0].category, .chores)
    }

    func testErrorEnvelopeDecoding() throws {
        let json = """
        {
            "error": {
                "code": "validation_error",
                "message": "Email already exists",
                "request_id": "req-123",
                "details": {
                    "field": "email"
                }
            }
        }
        """.data(using: .utf8)!

        let envelope = try decoder.decode(ErrorEnvelope.self, from: json)
        XCTAssertEqual(envelope.error.code, "validation_error")
        XCTAssertEqual(envelope.error.message, "Email already exists")
        XCTAssertEqual(envelope.error.details?.field, "email")
    }

    func testDeviceTokenResponseDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440050",
            "user_id": "550e8400-e29b-41d4-a716-446655440051",
            "platform": "ios",
            "token": "abc123def456",
            "created_at": "2026-02-16T14:12:00+00:00",
            "last_used_at": null
        }
        """.data(using: .utf8)!

        let device = try decoder.decode(DeviceTokenResponse.self, from: json)
        XCTAssertEqual(device.platform, .ios)
        XCTAssertEqual(device.token, "abc123def456")
        XCTAssertNil(device.lastUsedAt)
    }

    func testNagResponseWithRecurrenceDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "family_id": "550e8400-e29b-41d4-a716-446655440002",
            "creator_id": "550e8400-e29b-41d4-a716-446655440003",
            "recipient_id": "550e8400-e29b-41d4-a716-446655440004",
            "due_at": "2026-02-17T10:00:00+00:00",
            "category": "meds",
            "done_definition": "binary_check",
            "description": "Take vitamins",
            "strategy_template": "friendly_reminder",
            "recurrence": "daily",
            "status": "open",
            "created_at": "2026-02-16T14:12:00+00:00"
        }
        """.data(using: .utf8)!

        let nag = try decoder.decode(NagResponse.self, from: json)
        XCTAssertEqual(nag.recurrence, .daily)
        XCTAssertEqual(nag.category, .meds)
        XCTAssertEqual(nag.doneDefinition, .binaryCheck)
    }

    func testNagResponseWithoutRecurrenceDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "family_id": "550e8400-e29b-41d4-a716-446655440002",
            "creator_id": "550e8400-e29b-41d4-a716-446655440003",
            "recipient_id": "550e8400-e29b-41d4-a716-446655440004",
            "due_at": "2026-02-17T10:00:00+00:00",
            "category": "chores",
            "done_definition": "ack_only",
            "strategy_template": "friendly_reminder",
            "status": "completed",
            "created_at": "2026-02-16T14:12:00+00:00"
        }
        """.data(using: .utf8)!

        let nag = try decoder.decode(NagResponse.self, from: json)
        XCTAssertNil(nag.recurrence)
        XCTAssertEqual(nag.status, .completed)
    }

    func testVersionResponseDecoding() throws {
        let json = """
        {
            "server_version": "0.2.0",
            "api_version": "1.0.0",
            "min_client_version": "1.0.0"
        }
        """.data(using: .utf8)!

        let version = try decoder.decode(VersionResponse.self, from: json)
        XCTAssertEqual(version.serverVersion, "0.2.0")
        XCTAssertEqual(version.apiVersion, "1.0.0")
        XCTAssertEqual(version.minClientVersion, "1.0.0")
    }

    func testPolicyResponseDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440060",
            "family_id": "550e8400-e29b-41d4-a716-446655440061",
            "owners": ["550e8400-e29b-41d4-a716-446655440062"],
            "strategy_template": "friendly_reminder",
            "constraints": {},
            "status": "active"
        }
        """.data(using: .utf8)!

        // PolicyResponse has custom CodingKeys — use plain decoder (no convertFromSnakeCase)
        let plainDecoder = JSONDecoder()
        let policy = try plainDecoder.decode(PolicyResponse.self, from: json)
        XCTAssertEqual(policy.owners.count, 1)
        XCTAssertEqual(policy.strategyTemplate, .friendlyReminder)
        XCTAssertEqual(policy.status, "active")
    }

    func testPolicyResponseWithStringOwnersDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440060",
            "family_id": "550e8400-e29b-41d4-a716-446655440061",
            "owners": ["550e8400-e29b-41d4-a716-446655440062", "550e8400-e29b-41d4-a716-446655440063"],
            "strategy_template": "friendly_reminder",
            "constraints": {"max_nags": 5},
            "status": "active"
        }
        """.data(using: .utf8)!

        let plainDecoder = JSONDecoder()
        let policy = try plainDecoder.decode(PolicyResponse.self, from: json)
        XCTAssertEqual(policy.owners.count, 2)
    }

    func testApprovalResponseDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440070",
            "policy_id": "550e8400-e29b-41d4-a716-446655440071",
            "approver_id": "550e8400-e29b-41d4-a716-446655440072",
            "approved_at": "2026-02-16T14:12:00+00:00",
            "comment": "Looks good"
        }
        """.data(using: .utf8)!

        let approval = try decoder.decode(ApprovalResponse.self, from: json)
        XCTAssertEqual(approval.comment, "Looks good")
    }

    func testRecurrenceEnum() {
        XCTAssertEqual(Recurrence.daily.rawValue, "daily")
        XCTAssertEqual(Recurrence.weekly.rawValue, "weekly")
        XCTAssertEqual(Recurrence.monthly.rawValue, "monthly")
        XCTAssertEqual(Recurrence.daily.displayName, "Daily")
    }

    func testFamilyRolePermissions() {
        XCTAssertTrue(FamilyRole.guardian.canCreateNags)
        XCTAssertTrue(FamilyRole.participant.canCreateNags)
        XCTAssertFalse(FamilyRole.child.canCreateNags)

        XCTAssertTrue(FamilyRole.guardian.canViewAllNags)
        XCTAssertFalse(FamilyRole.participant.canViewAllNags)
        XCTAssertFalse(FamilyRole.child.canViewAllNags)

        XCTAssertTrue(FamilyRole.guardian.isAdmin)
        XCTAssertFalse(FamilyRole.participant.isAdmin)
        XCTAssertFalse(FamilyRole.child.isAdmin)
    }

    @MainActor func testVersionCheckerEvaluateCompatible() {
        let status = VersionChecker.evaluate(serverAPI: "1.0.0", minClient: "1.0.0")
        if case .compatible = status {} else {
            XCTFail("Expected compatible, got \(status)")
        }
    }

    @MainActor func testVersionCheckerEvaluateUpdateRequired() {
        let status = VersionChecker.evaluate(serverAPI: "2.0.0", minClient: "1.5.0")
        if case .updateRequired = status {} else {
            XCTFail("Expected updateRequired, got \(status)")
        }
    }

    @MainActor func testVersionCheckerEvaluateUpdateRecommended() {
        let status = VersionChecker.evaluate(serverAPI: "2.0.0", minClient: "1.0.0")
        if case .updateRecommended = status {} else {
            XCTFail("Expected updateRecommended, got \(status)")
        }
    }

    func testEnumRawValues() {
        XCTAssertEqual(NagCategory.chores.rawValue, "chores")
        XCTAssertEqual(DoneDefinition.ackOnly.rawValue, "ack_only")
        XCTAssertEqual(EscalationPhase.phase3OverdueBoundedPushback.rawValue, "phase_3_overdue_bounded_pushback")
        XCTAssertEqual(NagStatus.cancelledRelationshipChange.rawValue, "cancelled_relationship_change")
        XCTAssertEqual(StrategyTemplate.friendlyReminder.rawValue, "friendly_reminder")
    }

    // MARK: - APIError Tests

    func testAPIErrorIsRetryable() {
        // Retryable errors
        let networkErr = APIError.networkError(URLError(.notConnectedToInternet))
        XCTAssertTrue(networkErr.isRetryable)

        let serverErr = APIError.serverError("Internal Server Error")
        XCTAssertTrue(serverErr.isRetryable)

        let rateLimited = APIError.rateLimited
        XCTAssertTrue(rateLimited.isRetryable)

        // Non-retryable errors
        XCTAssertFalse(APIError.unauthorized.isRetryable)
        XCTAssertFalse(APIError.notFound.isRetryable)
        XCTAssertFalse(APIError.forbidden.isRetryable)
        XCTAssertFalse(APIError.invalidURL.isRetryable)
        XCTAssertFalse(APIError.validationError("bad input").isRetryable)
        XCTAssertFalse(APIError.decodingError(URLError(.badURL)).isRetryable)
        XCTAssertFalse(APIError.unknown(418, "teapot").isRetryable)
    }

    func testAPIErrorDescriptions() {
        let cases: [APIError] = [
            .invalidURL,
            .unauthorized,
            .forbidden,
            .notFound,
            .rateLimited,
            .validationError("field required"),
            .serverError("oops"),
            .networkError(URLError(.notConnectedToInternet)),
            .decodingError(URLError(.badURL)),
            .unknown(500, "something")
        ]
        for apiError in cases {
            XCTAssertNotNil(apiError.errorDescription, "errorDescription should not be nil for \(apiError)")
            XCTAssertFalse(apiError.errorDescription!.isEmpty, "errorDescription should not be empty for \(apiError)")
        }

        // Verify specific descriptions
        XCTAssertEqual(APIError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(APIError.unauthorized.errorDescription, "Session expired. Please log in again.")
        XCTAssertEqual(APIError.forbidden.errorDescription, "You don't have permission for this action.")
        XCTAssertEqual(APIError.notFound.errorDescription, "The requested resource was not found.")
        XCTAssertEqual(APIError.rateLimited.errorDescription, "Too many requests. Please wait a moment and try again.")
        XCTAssertEqual(APIError.validationError("field required").errorDescription, "field required")
        XCTAssertTrue(APIError.serverError("oops").errorDescription!.contains("oops"))
        XCTAssertTrue(APIError.unknown(418, "teapot").errorDescription!.contains("418"))
    }

    // MARK: - Additional Enum Tests

    func testAllNagStatusValues() {
        XCTAssertEqual(NagStatus.open.rawValue, "open")
        XCTAssertEqual(NagStatus.completed.rawValue, "completed")
        XCTAssertEqual(NagStatus.missed.rawValue, "missed")
        XCTAssertEqual(NagStatus.cancelledRelationshipChange.rawValue, "cancelled_relationship_change")
    }

    func testAllNagCategoryValues() {
        let allCases = NagCategory.allCases
        XCTAssertEqual(allCases.count, 5)

        XCTAssertEqual(NagCategory.chores.rawValue, "chores")
        XCTAssertEqual(NagCategory.meds.rawValue, "meds")
        XCTAssertEqual(NagCategory.homework.rawValue, "homework")
        XCTAssertEqual(NagCategory.appointments.rawValue, "appointments")
        XCTAssertEqual(NagCategory.other.rawValue, "other")

        // Verify display names
        XCTAssertEqual(NagCategory.chores.displayName, "Chores")
        XCTAssertEqual(NagCategory.meds.displayName, "Meds")
        XCTAssertEqual(NagCategory.homework.displayName, "Homework")
        XCTAssertEqual(NagCategory.appointments.displayName, "Appointments")
        XCTAssertEqual(NagCategory.other.displayName, "Other")
    }

    func testAllDoneDefinitionValues() {
        let allCases = DoneDefinition.allCases
        XCTAssertEqual(allCases.count, 3)

        XCTAssertEqual(DoneDefinition.ackOnly.rawValue, "ack_only")
        XCTAssertEqual(DoneDefinition.binaryCheck.rawValue, "binary_check")
        XCTAssertEqual(DoneDefinition.binaryWithNote.rawValue, "binary_with_note")

        // Verify display names
        XCTAssertEqual(DoneDefinition.ackOnly.displayName, "Acknowledge")
        XCTAssertEqual(DoneDefinition.binaryCheck.displayName, "Check Off")
        XCTAssertEqual(DoneDefinition.binaryWithNote.displayName, "Check Off + Note")
    }

    func testEscalationPhaseOrdering() {
        let phases: [EscalationPhase] = [
            .phase0Initial,
            .phase1DueSoon,
            .phase2OverdueSoft,
            .phase3OverdueBoundedPushback,
            .phase4GuardianReview
        ]

        // Verify each phase is less than the next
        for i in 0..<phases.count - 1 {
            XCTAssertTrue(phases[i] < phases[i + 1],
                "\(phases[i]) should be less than \(phases[i + 1])")
        }

        // Verify first < last
        XCTAssertTrue(EscalationPhase.phase0Initial < EscalationPhase.phase4GuardianReview)

        // Verify not less than self
        XCTAssertFalse(EscalationPhase.phase2OverdueSoft < EscalationPhase.phase2OverdueSoft)

        // Verify reverse is not less than
        XCTAssertFalse(EscalationPhase.phase4GuardianReview < EscalationPhase.phase0Initial)
    }

    // MARK: - Safety Models Decoding Tests

    func testSafetyBlockResponseDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440080",
            "actor_id": "550e8400-e29b-41d4-a716-446655440081",
            "target_id": "550e8400-e29b-41d4-a716-446655440082",
            "state": "active"
        }
        """.data(using: .utf8)!

        let block = try decoder.decode(BlockResponse.self, from: json)
        XCTAssertEqual(block.id, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440080"))
        XCTAssertEqual(block.actorId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440081"))
        XCTAssertEqual(block.targetId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440082"))
        XCTAssertEqual(block.state, .active)
    }

    func testSafetyAbuseReportResponseDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440083",
            "reporter_id": "550e8400-e29b-41d4-a716-446655440084",
            "target_id": "550e8400-e29b-41d4-a716-446655440085",
            "reason": "Inappropriate behavior",
            "status": "investigating"
        }
        """.data(using: .utf8)!

        let report = try decoder.decode(AbuseReportResponse.self, from: json)
        XCTAssertEqual(report.id, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440083"))
        XCTAssertEqual(report.reporterId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440084"))
        XCTAssertEqual(report.targetId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440085"))
        XCTAssertEqual(report.reason, "Inappropriate behavior")
        XCTAssertEqual(report.status, .investigating)
    }

    // MARK: - Consent Models Decoding Tests

    func testConsentModelsDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440090",
            "user_id": "550e8400-e29b-41d4-a716-446655440091",
            "family_id_nullable": "550e8400-e29b-41d4-a716-446655440092",
            "consent_type": "sms_opt_in"
        }
        """.data(using: .utf8)!

        let consent = try decoder.decode(ConsentResponse.self, from: json)
        XCTAssertEqual(consent.id, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440090"))
        XCTAssertEqual(consent.userId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440091"))
        XCTAssertEqual(consent.familyIdNullable, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440092"))
        XCTAssertEqual(consent.consentType, .smsOptIn)
    }

    func testConsentModelsDecodingWithNullFamily() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440090",
            "user_id": "550e8400-e29b-41d4-a716-446655440091",
            "family_id_nullable": null,
            "consent_type": "child_account_creation"
        }
        """.data(using: .utf8)!

        let consent = try decoder.decode(ConsentResponse.self, from: json)
        XCTAssertNil(consent.familyIdNullable)
        XCTAssertEqual(consent.consentType, .childAccountCreation)
    }

    // MARK: - Gamification Models Decoding Tests

    func testGamificationSummaryDecoding() throws {
        let json = """
        {
            "family_id": "550e8400-e29b-41d4-a716-446655440100",
            "user_id": "550e8400-e29b-41d4-a716-446655440101",
            "total_points": 250,
            "current_streak": 7,
            "event_count": 42
        }
        """.data(using: .utf8)!

        let summary = try decoder.decode(GamificationSummary.self, from: json)
        XCTAssertEqual(summary.familyId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440100"))
        XCTAssertEqual(summary.userId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440101"))
        XCTAssertEqual(summary.totalPoints, 250)
        XCTAssertEqual(summary.currentStreak, 7)
        XCTAssertEqual(summary.eventCount, 42)
    }

    func testLeaderboardEntryDecoding() throws {
        let json = """
        {
            "user_id": "550e8400-e29b-41d4-a716-446655440110",
            "total_points": 500
        }
        """.data(using: .utf8)!

        let entry = try decoder.decode(LeaderboardEntry.self, from: json)
        XCTAssertEqual(entry.userId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440110"))
        XCTAssertEqual(entry.totalPoints, 500)
        XCTAssertEqual(entry.id, entry.userId)
    }

    func testLeaderboardResponseDecoding() throws {
        let json = """
        {
            "family_id": "550e8400-e29b-41d4-a716-446655440120",
            "period_start": "2026-02-10T00:00:00+00:00",
            "leaderboard": [
                {"user_id": "550e8400-e29b-41d4-a716-446655440121", "total_points": 300},
                {"user_id": "550e8400-e29b-41d4-a716-446655440122", "total_points": 150}
            ]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(LeaderboardResponse.self, from: json)
        XCTAssertEqual(response.familyId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440120"))
        XCTAssertEqual(response.leaderboard.count, 2)
        XCTAssertEqual(response.leaderboard[0].totalPoints, 300)
        XCTAssertEqual(response.leaderboard[1].totalPoints, 150)
    }

    // MARK: - Report Models Decoding Tests

    func testReportModelsDecoding() throws {
        // ReportMetrics no longer has custom CodingKeys — convertFromSnakeCase handles it
        let json = """
        {
            "family_id": "550e8400-e29b-41d4-a716-446655440130",
            "period_start": "2026-02-10T00:00:00+00:00",
            "metrics": {
                "total_nags": 20,
                "completed": 15,
                "missed": 5
            }
        }
        """.data(using: .utf8)!

        let report = try decoder.decode(WeeklyReportResponse.self, from: json)
        XCTAssertEqual(report.familyId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440130"))
        XCTAssertEqual(report.metrics.totalNags, 20)
        XCTAssertEqual(report.metrics.completed, 15)
        XCTAssertEqual(report.metrics.missed, 5)
    }

    // MARK: - Excuse Models Decoding Tests

    func testExcuseModelsDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440140",
            "nag_id": "550e8400-e29b-41d4-a716-446655440141",
            "summary": "I was too tired",
            "at": "2026-02-16T18:30:00+00:00"
        }
        """.data(using: .utf8)!

        let excuse = try decoder.decode(ExcuseResponse.self, from: json)
        XCTAssertEqual(excuse.id, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440140"))
        XCTAssertEqual(excuse.nagId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440141"))
        XCTAssertEqual(excuse.summary, "I was too tired")
        XCTAssertNotNil(excuse.at)
    }

    func testExcuseModelsDecodingWithoutAt() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440142",
            "nag_id": "550e8400-e29b-41d4-a716-446655440143",
            "summary": "Dog ate my homework"
        }
        """.data(using: .utf8)!

        let excuse = try decoder.decode(ExcuseResponse.self, from: json)
        XCTAssertEqual(excuse.summary, "Dog ate my homework")
        XCTAssertNil(excuse.at)
    }

    // MARK: - Preference Models Decoding Tests

    func testPreferenceModelsDecoding() throws {
        let json = """
        {
            "user_id": "550e8400-e29b-41d4-a716-446655440150",
            "family_id": "550e8400-e29b-41d4-a716-446655440151",
            "schema_version": 1,
            "prefs_json": {
                "dark_mode": true,
                "language": "en",
                "max_nags": 10
            },
            "etag": "abc123etag",
            "updated_at": "2026-02-16T14:12:00+00:00"
        }
        """.data(using: .utf8)!

        let prefs = try decoder.decode(PreferenceResponse.self, from: json)
        XCTAssertEqual(prefs.userId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440150"))
        XCTAssertEqual(prefs.familyId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440151"))
        XCTAssertEqual(prefs.schemaVersion, 1)
        XCTAssertEqual(prefs.etag, "abc123etag")
        // convertFromSnakeCase only converts CodingKeys, not dictionary string keys,
        // so inner dict keys stay as-is from the JSON.
        XCTAssertEqual(prefs.prefsJson["dark_mode"], .bool(true))
        XCTAssertEqual(prefs.prefsJson["language"], .string("en"))
        XCTAssertEqual(prefs.prefsJson["max_nags"], .int(10))
    }

    // MARK: - APIEndpoint Tests

    func testEndpointCacheKey() {
        let endpoint = APIEndpoint(
            path: "/nags",
            queryItems: [
                URLQueryItem(name: "family_id", value: "abc"),
                URLQueryItem(name: "status", value: "open")
            ]
        )
        let key = endpoint.cacheKey
        // cacheKey sorts query items alphabetically
        XCTAssertEqual(key, "/nags?family_id=abc&status=open")
    }

    func testEndpointCacheKeyNoQueryItems() {
        let endpoint = APIEndpoint(path: "/version", requiresAuth: false)
        XCTAssertEqual(endpoint.cacheKey, "/version")
    }

    func testEndpointCacheKeyConsistency() {
        // Same path and same query items in different order should produce the same cache key
        let endpoint1 = APIEndpoint(
            path: "/nags",
            queryItems: [
                URLQueryItem(name: "status", value: "open"),
                URLQueryItem(name: "family_id", value: "abc")
            ]
        )
        let endpoint2 = APIEndpoint(
            path: "/nags",
            queryItems: [
                URLQueryItem(name: "family_id", value: "abc"),
                URLQueryItem(name: "status", value: "open")
            ]
        )
        XCTAssertEqual(endpoint1.cacheKey, endpoint2.cacheKey)
    }

    func testEndpointCacheKeyDifferentParams() {
        let endpoint1 = APIEndpoint(
            path: "/nags",
            queryItems: [URLQueryItem(name: "status", value: "open")]
        )
        let endpoint2 = APIEndpoint(
            path: "/nags",
            queryItems: [URLQueryItem(name: "status", value: "completed")]
        )
        XCTAssertNotEqual(endpoint1.cacheKey, endpoint2.cacheKey)
    }

    // MARK: - Connection trusted field tests

    func testConnectionResponseDecodingWithTrusted() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "inviter_id": "550e8400-e29b-41d4-a716-446655440001",
            "invitee_id": "550e8400-e29b-41d4-a716-446655440002",
            "invitee_email": "bob@example.com",
            "status": "active",
            "trusted": true,
            "created_at": "2026-02-25T12:00:00+00:00",
            "responded_at": "2026-02-25T12:30:00+00:00"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ConnectionResponse.self, from: json)
        XCTAssertEqual(response.inviteeEmail, "bob@example.com")
        XCTAssertEqual(response.status, .active)
        XCTAssertTrue(response.trusted)
        XCTAssertNotNil(response.inviteeId)
    }

    func testConnectionResponseDecodingUntrusted() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "inviter_id": "550e8400-e29b-41d4-a716-446655440001",
            "invitee_id": null,
            "invitee_email": "bob@example.com",
            "status": "pending",
            "trusted": false,
            "created_at": "2026-02-25T12:00:00+00:00",
            "responded_at": null
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ConnectionResponse.self, from: json)
        XCTAssertFalse(response.trusted)
        XCTAssertNil(response.inviteeId)
        XCTAssertEqual(response.status, .pending)
    }

    func testTrustedConnectionChildDecoding() throws {
        let json = """
        {
            "user_id": "550e8400-e29b-41d4-a716-446655440010",
            "display_name": "Kid One",
            "family_id": "550e8400-e29b-41d4-a716-446655440020",
            "family_name": "Bob's Family",
            "connection_id": "550e8400-e29b-41d4-a716-446655440030"
        }
        """.data(using: .utf8)!

        let child = try decoder.decode(TrustedConnectionChild.self, from: json)
        XCTAssertEqual(child.displayName, "Kid One")
        XCTAssertEqual(child.familyName, "Bob's Family")
        XCTAssertEqual(child.userId, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440010"))
        XCTAssertEqual(child.id, child.userId)
    }

    func testConnectionTrustUpdateEncoding() throws {
        let update = ConnectionTrustUpdate(trusted: true)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(update)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(dict["trusted"] as? Bool, true)
    }

    // MARK: - Connection trust endpoint path tests

    func testUpdateConnectionTrustEndpointPath() {
        let id = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
        let endpoint = APIEndpoint.updateConnectionTrust(id: id, trusted: true)
        XCTAssertTrue(endpoint.path.contains("/connections/"))
        XCTAssertTrue(endpoint.path.hasSuffix("/trust"))
        XCTAssertEqual(endpoint.method, .patch)
    }

    func testListTrustedChildrenEndpointPath() {
        let id = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
        let endpoint = APIEndpoint.listTrustedChildren(connectionId: id)
        XCTAssertTrue(endpoint.path.contains("/connections/"))
        XCTAssertTrue(endpoint.path.hasSuffix("/children"))
        XCTAssertEqual(endpoint.method, .get)
    }
}
