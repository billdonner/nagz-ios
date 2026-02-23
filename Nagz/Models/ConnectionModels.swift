import Foundation

struct ConnectionResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let inviterId: UUID
    let inviteeId: UUID?
    let inviteeEmail: String
    let status: ConnectionStatus
    let createdAt: Date
    let respondedAt: Date?
}

struct ConnectionInvite: Encodable {
    let inviteeEmail: String
}
