import XCTest
@testable import Nagz

final class ScheduleViewTests: XCTestCase {

    // Fixed reference date: 2026-03-02 at noon UTC
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-03-02T12:00:00Z")!
    private let meId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let otherId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

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

    private func makeNag(
        id: String = UUID().uuidString,
        creatorId: UUID? = nil,
        recipientId: UUID? = nil,
        dueAt: String,
        committedAt: String? = nil,
        status: String = "open",
        category: String = "chores"
    ) -> NagResponse {
        let creator = (creatorId ?? otherId).uuidString
        let recipient = (recipientId ?? meId).uuidString
        let committedLine = committedAt.map { ",\"committed_at\":\"\($0)\"" } ?? ""
        let json = """
        {
            "id": "\(id)",
            "creator_id": "\(creator)",
            "recipient_id": "\(recipient)",
            "due_at": "\(dueAt)",
            "category": "\(category)",
            "done_definition": "ack_only",
            "strategy_template": "friendly_reminder",
            "status": "\(status)",
            "created_at": "2026-03-01T10:00:00Z"
            \(committedLine)
        }
        """
        return try! decoder.decode(NagResponse.self, from: json.data(using: .utf8)!)
    }

    private func group(
        nagsForMe: [NagResponse] = [],
        nagsForOthers: [NagResponse] = [],
        selfNags: [NagResponse] = []
    ) -> [ScheduleNagListView.ScheduleSection] {
        ScheduleNagListView.groupNagsByDate(
            nagsForMe: nagsForMe,
            nagsForOthers: nagsForOthers,
            selfNags: selfNags,
            currentUserId: meId,
            referenceDate: referenceDate
        )
    }

    // MARK: - Tests

    func testGroupsNagsByDay() {
        // Nags on different days land in different sections
        let todayNag = makeNag(dueAt: "2026-03-02T14:00:00Z", committedAt: "2026-03-02T14:00:00Z")
        let tomorrowNag = makeNag(dueAt: "2026-03-03T10:00:00Z", committedAt: "2026-03-03T10:00:00Z")

        let sections = group(nagsForMe: [todayNag, tomorrowNag])
        let kinds = sections.map(\.kind)

        XCTAssertTrue(kinds.contains(.today))
        XCTAssertTrue(kinds.contains(.tomorrow))
    }

    func testOverdueSection() {
        // Open nag past due appears in overdue
        let pastNag = makeNag(dueAt: "2026-02-28T10:00:00Z", status: "open")
        // Has no committedAt so it goes to unscheduled instead
        let pastScheduledNag = makeNag(dueAt: "2026-02-28T10:00:00Z", committedAt: "2026-02-28T10:00:00Z", status: "open")

        let sections = group(nagsForMe: [pastScheduledNag])
        let overdueSection = sections.first { $0.kind == .overdue }
        XCTAssertNotNil(overdueSection)
        XCTAssertEqual(overdueSection?.nags.count, 1)

        // Unscheduled open past nag goes to unscheduled, not overdue
        let sections2 = group(nagsForMe: [pastNag])
        let unscheduled = sections2.first { $0.kind == .unscheduled }
        XCTAssertNotNil(unscheduled)
    }

    func testUnscheduledForReceivedNags() {
        // Received nag (from other person) with no committedAt and status open → unscheduled
        let nag = makeNag(creatorId: otherId, recipientId: meId, dueAt: "2026-03-05T10:00:00Z", status: "open")
        let sections = group(nagsForMe: [nag])

        let unscheduled = sections.first { $0.kind == .unscheduled }
        XCTAssertNotNil(unscheduled)
        XCTAssertEqual(unscheduled?.nags.count, 1)
        XCTAssertTrue(unscheduled?.nags.first?.canSchedule ?? false)
    }

    func testSentNagsNotUnscheduled() {
        // Sent nag without committedAt goes under dueAt day, not unscheduled
        let nag = makeNag(creatorId: meId, recipientId: otherId, dueAt: "2026-03-03T10:00:00Z", status: "open")
        let sections = group(nagsForOthers: [nag])

        let unscheduled = sections.first { $0.kind == .unscheduled }
        XCTAssertNil(unscheduled, "Sent nags should not appear in unscheduled")

        let tomorrow = sections.first { $0.kind == .tomorrow }
        XCTAssertNotNil(tomorrow)
    }

    func testCommittedAtPriority() {
        // committedAt is used over dueAt for grouping
        // dueAt is tomorrow, but committedAt is today → should be in "today"
        let nag = makeNag(
            dueAt: "2026-03-03T10:00:00Z",
            committedAt: "2026-03-02T15:00:00Z"
        )
        let sections = group(nagsForMe: [nag])

        let today = sections.first { $0.kind == .today }
        XCTAssertNotNil(today)
        XCTAssertEqual(today?.nags.count, 1)

        let tomorrow = sections.first { $0.kind == .tomorrow }
        XCTAssertNil(tomorrow)
    }

    func testWithinSectionSort() {
        // Within a section, nags sorted by time ascending
        let earlyNag = makeNag(
            id: "00000000-0000-0000-0000-000000000010",
            dueAt: "2026-03-02T09:00:00Z",
            committedAt: "2026-03-02T09:00:00Z"
        )
        let lateNag = makeNag(
            id: "00000000-0000-0000-0000-000000000011",
            dueAt: "2026-03-02T18:00:00Z",
            committedAt: "2026-03-02T18:00:00Z"
        )
        // Insert in reverse order
        let sections = group(nagsForMe: [lateNag, earlyNag])

        let today = sections.first { $0.kind == .today }
        XCTAssertNotNil(today)
        XCTAssertEqual(today?.nags.count, 2)
        // First entry should be the earlier nag
        XCTAssertEqual(today?.nags.first?.nag.id, earlyNag.id)
        XCTAssertEqual(today?.nags.last?.nag.id, lateNag.id)
    }

    func testCompletedNotOverdue() {
        // Completed nags in the past should NOT appear in overdue
        let nag = makeNag(dueAt: "2026-02-28T10:00:00Z", committedAt: "2026-02-28T10:00:00Z", status: "completed")
        let sections = group(nagsForMe: [nag])

        let overdue = sections.first { $0.kind == .overdue }
        XCTAssertNil(overdue, "Completed nags should not be in overdue")
    }

    func testSelfNagsNotUnscheduled() {
        // Self-nags go under dueAt day, not unscheduled, even without committedAt
        let nag = makeNag(creatorId: meId, recipientId: meId, dueAt: "2026-03-04T10:00:00Z", status: "open")
        let sections = group(selfNags: [nag])

        let unscheduled = sections.first { $0.kind == .unscheduled }
        XCTAssertNil(unscheduled, "Self-nags should not appear in unscheduled")

        // Should be in a future day section (March 4)
        let futureDay = sections.first { if case .futureDay = $0.kind { return true } else { return false } }
        XCTAssertNotNil(futureDay)
    }

    func testEmptyInput() {
        let sections = group()
        XCTAssertTrue(sections.isEmpty)
    }

    func testRelativeDateLabels() {
        // Today and Tomorrow labels are correct relative to reference date
        let todayNag = makeNag(dueAt: "2026-03-02T14:00:00Z", committedAt: "2026-03-02T14:00:00Z")
        let tomorrowNag = makeNag(dueAt: "2026-03-03T14:00:00Z", committedAt: "2026-03-03T14:00:00Z")

        let sections = group(nagsForMe: [todayNag, tomorrowNag])

        let todaySection = sections.first { $0.kind == .today }
        XCTAssertEqual(todaySection?.title, "Today")

        let tomorrowSection = sections.first { $0.kind == .tomorrow }
        XCTAssertEqual(tomorrowSection?.title, "Tomorrow")
    }
}
