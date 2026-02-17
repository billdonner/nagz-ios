import Foundation

struct ExcuseResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let nagId: UUID
    let summary: String
    let at: Date?

    // at may be missing on create response
    enum CodingKeys: String, CodingKey {
        case id, nagId, summary, at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        nagId = try container.decode(UUID.self, forKey: .nagId)
        summary = try container.decode(String.self, forKey: .summary)
        at = try container.decodeIfPresent(Date.self, forKey: .at)
    }
}

struct ExcuseCreate: Encodable {
    let text: String
    let category: String?

    init(text: String, category: String? = nil) {
        self.text = text
        self.category = category
    }
}
