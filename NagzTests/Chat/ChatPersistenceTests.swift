import XCTest
import GRDB
@testable import Nagz

final class ChatPersistenceTests: XCTestCase {

    private var db: DatabaseManager!

    override func setUp() async throws {
        try await super.setUp()
        db = try DatabaseManager.inMemory()

        // Insert a parent nag so FK constraint is satisfied
        let writer = await db.writer
        try await writer.write { db in
            try CachedNag(
                id: "nag-1",
                familyId: "fam-1",
                creatorId: "user-a",
                recipientId: "user-b",
                dueAt: Date(),
                category: "chores",
                doneDefinition: "ack_only",
                description: "Test nag",
                status: "open",
                createdAt: Date(),
                syncedAt: Date()
            ).insert(db)

            try CachedNag(
                id: "nag-2",
                familyId: "fam-1",
                creatorId: "user-a",
                recipientId: "user-b",
                dueAt: Date(),
                category: "meds",
                doneDefinition: "binary_check",
                description: "Second nag",
                status: "open",
                createdAt: Date(),
                syncedAt: Date()
            ).insert(db)
        }
    }

    // MARK: - Save and Fetch

    func testSaveAndFetchMessages() async throws {
        let msg1 = CachedChatMessage(
            id: UUID().uuidString,
            nagId: "nag-1",
            role: "assistant",
            content: "Hello! Let's talk.",
            timestamp: Date().timeIntervalSince1970
        )
        let msg2 = CachedChatMessage(
            id: UUID().uuidString,
            nagId: "nag-1",
            role: "user",
            content: "Can I skip this?",
            timestamp: Date().addingTimeInterval(1).timeIntervalSince1970
        )

        try await db.saveChatMessage(msg1)
        try await db.saveChatMessage(msg2)

        let fetched = try await db.chatMessages(forNagId: "nag-1")
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched[0].role, "assistant")
        XCTAssertEqual(fetched[1].role, "user")
    }

    // MARK: - Ordering

    func testMessagesOrderedByTimestamp() async throws {
        let earlier = Date().addingTimeInterval(-100)
        let later = Date()

        let msg1 = CachedChatMessage(
            id: UUID().uuidString,
            nagId: "nag-1",
            role: "user",
            content: "Later message",
            timestamp: later.timeIntervalSince1970
        )
        let msg2 = CachedChatMessage(
            id: UUID().uuidString,
            nagId: "nag-1",
            role: "assistant",
            content: "Earlier message",
            timestamp: earlier.timeIntervalSince1970
        )

        // Insert out of order
        try await db.saveChatMessage(msg1)
        try await db.saveChatMessage(msg2)

        let fetched = try await db.chatMessages(forNagId: "nag-1")
        XCTAssertEqual(fetched[0].content, "Earlier message")
        XCTAssertEqual(fetched[1].content, "Later message")
    }

    // MARK: - Delete

    func testDeleteMessagesForNag() async throws {
        let msg = CachedChatMessage(
            id: UUID().uuidString,
            nagId: "nag-1",
            role: "user",
            content: "Test",
            timestamp: Date().timeIntervalSince1970
        )
        try await db.saveChatMessage(msg)

        try await db.deleteChatMessages(forNagId: "nag-1")

        let fetched = try await db.chatMessages(forNagId: "nag-1")
        XCTAssertTrue(fetched.isEmpty)
    }

    // MARK: - Empty Fetch

    func testFetchReturnsEmptyForUnknownNag() async throws {
        let fetched = try await db.chatMessages(forNagId: "nonexistent-nag-999")
        XCTAssertTrue(fetched.isEmpty)
    }

    // MARK: - Isolation

    func testMultipleNagsHaveIsolatedHistories() async throws {
        let msg1 = CachedChatMessage(
            id: UUID().uuidString,
            nagId: "nag-1",
            role: "user",
            content: "Message for nag 1",
            timestamp: Date().timeIntervalSince1970
        )
        let msg2 = CachedChatMessage(
            id: UUID().uuidString,
            nagId: "nag-2",
            role: "assistant",
            content: "Message for nag 2",
            timestamp: Date().timeIntervalSince1970
        )

        try await db.saveChatMessage(msg1)
        try await db.saveChatMessage(msg2)

        let nag1Messages = try await db.chatMessages(forNagId: "nag-1")
        let nag2Messages = try await db.chatMessages(forNagId: "nag-2")

        XCTAssertEqual(nag1Messages.count, 1)
        XCTAssertEqual(nag1Messages[0].content, "Message for nag 1")

        XCTAssertEqual(nag2Messages.count, 1)
        XCTAssertEqual(nag2Messages[0].content, "Message for nag 2")
    }

    // MARK: - Migration

    func testMigrationV2CreatesTableAndIndex() async throws {
        // If we got here without crashing, migration v2 ran successfully.
        // Verify we can insert and read from the table.
        let msg = CachedChatMessage(
            id: UUID().uuidString,
            nagId: "nag-1",
            role: "system",
            content: "Migration test",
            timestamp: Date().timeIntervalSince1970
        )
        try await db.saveChatMessage(msg)

        let fetched = try await db.chatMessages(forNagId: "nag-1")
        XCTAssertEqual(fetched.count, 1)

        // Verify index exists by checking sqlite_master
        let reader = await db.reader
        let indexExists = try await reader.read { db -> Bool in
            let row = try Row.fetchOne(
                db,
                sql: "SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type='index' AND name='idx_chat_messages_nag'"
            )
            return (row?["cnt"] as? Int ?? 0) > 0
        }
        XCTAssertTrue(indexExists)
    }
}
