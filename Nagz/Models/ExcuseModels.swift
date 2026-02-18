import Foundation

struct ExcuseResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let nagId: UUID
    let summary: String
    let at: Date?
}

struct ExcuseCreate: Encodable {
    let text: String
    let category: String?

    init(text: String, category: String? = nil) {
        self.text = text
        self.category = category
    }
}
