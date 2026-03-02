#if canImport(FoundationModels)
import XCTest
import FoundationModels
@testable import Nagz

final class ChatToolTests: XCTestCase {

    // MARK: - Tool Name Tests

    func testRescheduleToolName() {
        let tool = RescheduleTool(
            nagId: UUID(),
            apiClient: Self.makeAPIClient(),
            collector: ToolResultCollector()
        )
        XCTAssertEqual(tool.name, "rescheduleNag")
    }

    func testCompleteToolName() {
        let tool = CompleteTool(
            nagId: UUID(),
            apiClient: Self.makeAPIClient(),
            collector: ToolResultCollector()
        )
        XCTAssertEqual(tool.name, "completeNag")
    }

    func testExcuseToolName() {
        let tool = ExcuseTool(
            nagId: UUID(),
            apiClient: Self.makeAPIClient(),
            collector: ToolResultCollector()
        )
        XCTAssertEqual(tool.name, "submitExcuse")
    }

    // MARK: - Tool Description Tests

    func testRescheduleToolDescriptionMentionsTomorrowAndLater() {
        let tool = RescheduleTool(
            nagId: UUID(),
            apiClient: Self.makeAPIClient(),
            collector: ToolResultCollector()
        )
        XCTAssertTrue(tool.description.lowercased().contains("tomorrow") || tool.description.lowercased().contains("later"),
                       "RescheduleTool description should mention 'tomorrow' or 'later'")
    }

    func testCompleteToolDescriptionMentionsAlreadyCompleted() {
        let tool = CompleteTool(
            nagId: UUID(),
            apiClient: Self.makeAPIClient(),
            collector: ToolResultCollector()
        )
        let desc = tool.description.lowercased()
        XCTAssertTrue(desc.contains("already") || desc.contains("finished"),
                       "CompleteTool description should mention 'already' or 'finished'")
    }

    func testCompleteToolDescriptionWarnsAgainstFutureTense() {
        let tool = CompleteTool(
            nagId: UUID(),
            apiClient: Self.makeAPIClient(),
            collector: ToolResultCollector()
        )
        let desc = tool.description.lowercased()
        XCTAssertTrue(desc.contains("never") || desc.contains("not"),
                       "CompleteTool description should warn against incorrect usage")
    }

    func testExcuseToolDescriptionMentionsExcuseAndReview() {
        let tool = ExcuseTool(
            nagId: UUID(),
            apiClient: Self.makeAPIClient(),
            collector: ToolResultCollector()
        )
        let desc = tool.description.lowercased()
        XCTAssertTrue(desc.contains("excuse") || desc.contains("reason"),
                       "ExcuseTool description should mention 'excuse' or 'reason'")
        XCTAssertTrue(desc.contains("review"),
                       "ExcuseTool description should mention 'review'")
    }

    // MARK: - ToolResultCollector Tests

    func testToolResultCollectorDrainReturnsRecordedActions() async {
        let collector = ToolResultCollector()
        await collector.record("✓ Rescheduled to tomorrow")
        await collector.record("✓ Marked as complete")

        let actions = await collector.drain()
        XCTAssertEqual(actions.count, 2)
        XCTAssertEqual(actions[0], "✓ Rescheduled to tomorrow")
        XCTAssertEqual(actions[1], "✓ Marked as complete")
    }

    func testToolResultCollectorDrainClearsAfterRead() async {
        let collector = ToolResultCollector()
        await collector.record("✓ Action 1")

        let first = await collector.drain()
        XCTAssertEqual(first.count, 1)

        let second = await collector.drain()
        XCTAssertTrue(second.isEmpty)
    }

    // MARK: - Helpers

    private static func makeAPIClient() -> APIClient {
        let keychain = KeychainService()
        return APIClient(
            baseURL: URL(string: "http://127.0.0.1:1/api/v1")!,
            keychainService: keychain
        )
    }
}

#endif
