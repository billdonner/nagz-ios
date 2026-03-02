import Foundation

struct ChatMessage: Identifiable, Sendable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }

    init(role: Role, content: String, timestamp: Date) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    enum Role: Sendable {
        case user, assistant, system

        init(rawValue: String) {
            switch rawValue {
            case "user": self = .user
            case "assistant": self = .assistant
            default: self = .system
            }
        }

        var rawString: String {
            switch self {
            case .user: "user"
            case .assistant: "assistant"
            case .system: "system"
            }
        }
    }
}
