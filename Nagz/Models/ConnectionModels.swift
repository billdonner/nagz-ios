import Foundation

struct ConnectionResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let inviterId: UUID
    let inviteeId: UUID?
    let inviteeEmail: String
    let status: ConnectionStatus
    let trusted: Bool
    let createdAt: Date
    let respondedAt: Date?
}

struct ConnectionInvite: Encodable {
    let inviteeEmail: String
}

struct ConnectionTrustUpdate: Encodable {
    let trusted: Bool
}

struct TrustedConnectionChild: Decodable, Identifiable, Sendable {
    let userId: UUID
    let displayName: String?
    let familyId: UUID
    let familyName: String
    let connectionId: UUID

    var id: UUID { userId }
}
