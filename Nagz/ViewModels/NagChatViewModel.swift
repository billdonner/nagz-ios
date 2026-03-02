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
    private var databaseManager: DatabaseManager?
    private var nagId: UUID?

    func setupSession(
        nag: NagResponse,
        apiClient: APIClient,
        personality: AIPersonality,
        databaseManager: DatabaseManager? = nil,
        onMutated: @escaping @Sendable () async -> Void
    ) {
        self.databaseManager = databaseManager
        self.nagId = nag.id

        // Load persisted history (read-only — not replayed into LLM session)
        if let db = databaseManager {
            Task {
                do {
                    let cached = try await db.chatMessages(forNagId: nag.id.uuidString)
                    if !cached.isEmpty {
                        let restored = cached.map { msg in
                            ChatMessage(
                                role: ChatMessage.Role(rawValue: msg.role),
                                content: msg.content,
                                timestamp: Date(timeIntervalSince1970: msg.timestamp)
                            )
                        }
                        // Insert history before the greeting
                        messages.insert(contentsOf: restored, at: 0)
                    }
                } catch {
                    // Non-critical — just start fresh
                }
            }
        }

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
        let greetingMsg = ChatMessage(role: .assistant, content: greeting)
        messages.append(greetingMsg)
        persistMessage(greetingMsg)
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let session, let collector else { return }

        inputText = ""
        errorMessage = nil
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        persistMessage(userMsg)
        isGenerating = true

        do {
            let response = try await session.respond(to: text)

            // Check for tool actions that fired during this turn
            let toolActions = await collector.drain()
            for action in toolActions {
                let sysMsg = ChatMessage(role: .system, content: action)
                messages.append(sysMsg)
                persistMessage(sysMsg)
                nagWasMutated = true
            }

            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                let assistantMsg = ChatMessage(role: .assistant, content: content)
                messages.append(assistantMsg)
                persistMessage(assistantMsg)
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

    // MARK: - Private

    private func persistMessage(_ msg: ChatMessage) {
        guard let db = databaseManager, let nagId else { return }
        let cached = CachedChatMessage(
            id: msg.id.uuidString,
            nagId: nagId.uuidString,
            role: msg.role.rawString,
            content: msg.content,
            timestamp: msg.timestamp.timeIntervalSince1970
        )
        Task {
            try? await db.saveChatMessage(cached)
        }
    }
}

#endif
