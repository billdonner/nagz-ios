import Foundation
import GRDB

struct CachedChatMessage: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "cached_chat_messages"

    var id: String          // UUID string
    var nagId: String       // links to nag
    var role: String        // "user", "assistant", "system"
    var content: String
    var timestamp: Double   // Date.timeIntervalSince1970
}
