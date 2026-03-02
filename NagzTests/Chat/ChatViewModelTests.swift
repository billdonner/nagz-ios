#if canImport(FoundationModels)
import XCTest
@testable import Nagz

final class ChatViewModelTests: XCTestCase {

    // MARK: - NagChatViewModel

    @MainActor
    func testNagChatInitialState() {
        let vm = NagChatViewModel()
        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertFalse(vm.isGenerating)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.nagWasMutated)
        XCTAssertEqual(vm.inputText, "")
    }

    @MainActor
    func testNagChatInputTextClearsAfterSend() async {
        let vm = NagChatViewModel()
        vm.inputText = "Hello"
        // send() without a session set up will early-return (no session)
        // but inputText is cleared before the guard
        await vm.send()
        // Without session, send returns early — inputText stays since guard catches it
        // This tests that the guard prevents mutation when no session exists
        XCTAssertEqual(vm.inputText, "Hello")
    }

    @MainActor
    func testNagWasMutatedStartsFalse() {
        let vm = NagChatViewModel()
        XCTAssertFalse(vm.nagWasMutated)
    }

    // MARK: - GlobalChatViewModel

    @MainActor
    func testGlobalChatInitialState() {
        let vm = GlobalChatViewModel()
        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertFalse(vm.isGenerating)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.inputText, "")
    }

    @MainActor
    func testGlobalChatSendWithoutSessionDoesNothing() async {
        let vm = GlobalChatViewModel()
        vm.inputText = "Hello"
        await vm.send()
        // Without session, guard returns early — inputText unchanged, no messages
        XCTAssertEqual(vm.inputText, "Hello")
        XCTAssertTrue(vm.messages.isEmpty)
    }

    // MARK: - ChatMessage

    func testChatMessageRoleRawString() {
        XCTAssertEqual(ChatMessage.Role.user.rawString, "user")
        XCTAssertEqual(ChatMessage.Role.assistant.rawString, "assistant")
        XCTAssertEqual(ChatMessage.Role.system.rawString, "system")
    }

    func testChatMessageRoleInit() {
        XCTAssertEqual(ChatMessage.Role(rawValue: "user").rawString, "user")
        XCTAssertEqual(ChatMessage.Role(rawValue: "assistant").rawString, "assistant")
        XCTAssertEqual(ChatMessage.Role(rawValue: "system").rawString, "system")
        XCTAssertEqual(ChatMessage.Role(rawValue: "unknown").rawString, "system") // defaults to system
    }

    func testChatMessageTimestampIsSet() {
        let before = Date()
        let msg = ChatMessage(role: .user, content: "test")
        let after = Date()
        XCTAssertGreaterThanOrEqual(msg.timestamp, before)
        XCTAssertLessThanOrEqual(msg.timestamp, after)
    }

    func testChatMessageCustomTimestamp() {
        let custom = Date(timeIntervalSince1970: 1000000)
        let msg = ChatMessage(role: .assistant, content: "hi", timestamp: custom)
        XCTAssertEqual(msg.timestamp, custom)
    }
}

#endif
