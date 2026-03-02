#if canImport(FoundationModels)
import Foundation
import FoundationModels
import NagzAI

@Observable
@MainActor
final class GlobalChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isGenerating = false
    var errorMessage: String?
    private(set) var hasFamily = false

    private var session: LanguageModelSession?
    private var collector: ToolResultCollector?

    func reset() {
        messages = []
        inputText = ""
        isGenerating = false
        errorMessage = nil
        hasFamily = false
        session = nil
        collector = nil
    }

    func setupSession(
        apiClient: APIClient,
        currentUserId: UUID,
        familyId: UUID?,
        userName: String,
        familyName: String?,
        memberNames: [String],
        personality: AIPersonality
    ) {
        self.hasFamily = familyId != nil
        let toolCollector = ToolResultCollector()
        self.collector = toolCollector

        let listTool = ListNagsTool(
            apiClient: apiClient,
            familyId: familyId,
            currentUserId: currentUserId,
            collector: toolCollector
        )
        let createTool = CreateNagTool(
            apiClient: apiClient,
            familyId: familyId,
            currentUserId: currentUserId,
            userName: userName,
            collector: toolCollector
        )
        let completeTool = GlobalCompleteTool(
            apiClient: apiClient,
            familyId: familyId,
            currentUserId: currentUserId,
            collector: toolCollector
        )
        let rescheduleTool = GlobalRescheduleTool(
            apiClient: apiClient,
            familyId: familyId,
            currentUserId: currentUserId,
            collector: toolCollector
        )
        let statusTool = NagStatusTool(
            apiClient: apiClient,
            familyId: familyId,
            currentUserId: currentUserId,
            collector: toolCollector
        )
        let excuseTool = SubmitExcuseTool(
            apiClient: apiClient,
            familyId: familyId,
            currentUserId: currentUserId,
            collector: toolCollector
        )

        let instructions = GlobalChatPrompt.build(
            userName: userName,
            familyName: familyName,
            memberNames: memberNames,
            personality: personality
        )

        session = LanguageModelSession(
            tools: [listTool, createTool, completeTool, rescheduleTool, statusTool, excuseTool]
        ) {
            instructions
        }

        let greeting = GlobalChatPrompt.greeting(
            userName: userName,
            personality: personality
        )
        messages.append(ChatMessage(role: .assistant, content: greeting))
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let session, let collector else { return }

        inputText = ""
        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: text))
        isGenerating = true

        do {
            let response = try await session.respond(to: text)

            let toolActions = await collector.drain()
            for action in toolActions {
                messages.append(ChatMessage(role: .system, content: action))
            }

            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                messages.append(ChatMessage(role: .assistant, content: content))
            }
            // Show any tool actions even if the AI response was empty
            if toolActions.isEmpty && content.isEmpty {
                messages.append(ChatMessage(role: .assistant, content: "Done! Is there anything else I can help with?"))
            }
        } catch let error as LanguageModelSession.GenerationError {
            // Drain any tool actions that happened before the error
            let toolActions = await collector.drain()
            for action in toolActions {
                messages.append(ChatMessage(role: .system, content: action))
            }

            switch error {
            case .exceededContextWindowSize:
                errorMessage = "Conversation too long — please switch tabs and come back to start fresh."
            default:
                // error -1 is often a content/guardrail issue on the on-device model
                errorMessage = "Apple Intelligence couldn't process that. Try rephrasing your request."
            }
        } catch {
            errorMessage = "Something went wrong. Try again or rephrase your request."
        }

        isGenerating = false
    }
}

#endif
