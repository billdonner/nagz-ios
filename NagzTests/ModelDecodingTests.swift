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

    func testEnumRawValues() {
        XCTAssertEqual(NagCategory.chores.rawValue, "chores")
        XCTAssertEqual(DoneDefinition.ackOnly.rawValue, "ack_only")
        XCTAssertEqual(EscalationPhase.phase3OverdueBoundedPushback.rawValue, "phase_3_overdue_bounded_pushback")
        XCTAssertEqual(NagStatus.cancelledRelationshipChange.rawValue, "cancelled_relationship_change")
        XCTAssertEqual(StrategyTemplate.friendlyReminder.rawValue, "friendly_reminder")
    }
}
