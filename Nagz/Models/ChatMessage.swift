import Foundation

struct ChatMessage: Identifiable, Sendable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()

    enum Role: Sendable { case user, assistant, system }
}
