import Foundation

struct PaginatedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let items: [T]
    let total: Int
    let limit: Int
    let offset: Int

    var hasMore: Bool {
        offset + limit < total
    }

    var nextOffset: Int {
        offset + limit
    }
}
