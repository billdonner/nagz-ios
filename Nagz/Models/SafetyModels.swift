import Foundation

enum AbuseReportStatus: String, Codable, Sendable {
    case open
    case investigating
    case resolved
    case dismissed

    var displayName: String {
        rawValue.capitalized
    }
}

enum BlockState: String, Codable, Sendable {
    case active
    case lifted

    var displayName: String {
        rawValue.capitalized
    }
}

struct AbuseReportResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let reporterId: UUID
    let targetId: UUID
    let reason: String
    let status: AbuseReportStatus
}

struct AbuseReportCreate: Encodable {
    let targetId: UUID
    let reason: String
}

struct BlockResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let actorId: UUID
    let targetId: UUID
    let state: BlockState
}

struct BlockCreateRequest: Encodable {
    let targetId: UUID
}

struct BlockUpdateRequest: Encodable {
    let state: BlockState
}
