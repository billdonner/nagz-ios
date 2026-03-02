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

    private var session: LanguageModelSession?
    private var collector: ToolResultCollector?

    func setupSession(
        apiClient: APIClient,
        currentUserId: UUID,
        familyId: UUID?,
        userName: String,
        familyName: String?,
        memberNames: [String],
        personality: AIPersonality
    ) {
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

        let instructions = GlobalChatPrompt.build(
            userName: userName,
            familyName: familyName,
            memberNames: memberNames,
            personality: personality
        )

        session = LanguageModelSession(
            tools: [listTool, createTool, completeTool, rescheduleTool, statusTool]
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
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                errorMessage = "Conversation too long — start a new one."
            default:
                errorMessage = "AI unavailable: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Something went wrong: \(error.localizedDescription)"
        }

        isGenerating = false
    }
}

#endif
