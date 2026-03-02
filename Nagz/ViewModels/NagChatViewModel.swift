#if canImport(FoundationModels)
import Foundation
import FoundationModels
import NagzAI

@Observable
@MainActor
final class NagChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isGenerating = false
    var errorMessage: String?
    var nagWasMutated = false

    private var session: LanguageModelSession?
    private var collector: ToolResultCollector?

    func setupSession(
        nag: NagResponse,
        apiClient: APIClient,
        personality: AIPersonality,
        onMutated: @escaping @Sendable () async -> Void
    ) {
        let toolCollector = ToolResultCollector()
        self.collector = toolCollector

        let reschedule = RescheduleTool(
            nagId: nag.id,
            apiClient: apiClient,
            collector: toolCollector
        )
        let complete = CompleteTool(
            nagId: nag.id,
            apiClient: apiClient,
            collector: toolCollector
        )
        let excuse = ExcuseTool(
            nagId: nag.id,
            apiClient: apiClient,
            collector: toolCollector
        )

        let instructions = NagChatPrompt.build(
            category: nag.category.displayName,
            description: nag.description,
            dueAt: nag.dueAt,
            status: nag.status.rawValue,
            creatorName: nag.creatorDisplayName,
            personality: personality
        )

        session = LanguageModelSession(
            tools: [reschedule, complete, excuse]
        ) {
            instructions
        }

        // Add AI greeting
        let greeting = NagChatPrompt.greeting(
            category: nag.category.displayName,
            description: nag.description,
            dueAt: nag.dueAt,
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

            // Check for tool actions that fired during this turn
            let toolActions = await collector.drain()
            for action in toolActions {
                messages.append(ChatMessage(role: .system, content: action))
                nagWasMutated = true
            }

            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                messages.append(ChatMessage(role: .assistant, content: content))
            }
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                errorMessage = "This conversation got too long. Close and reopen to start fresh."
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
