import Foundation

struct ConnectionResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let inviterId: UUID
    let inviteeId: UUID?
    let inviteeEmail: String
    let status: ConnectionStatus
    let caregiver: Bool
    let createdAt: Date
    let respondedAt: Date?
    let otherPartyEmail: String?
    let otherPartyDisplayName: String?
}

struct ConnectionInvite: Encodable {
    let inviteeEmail: String
    let caregiver: Bool

    init(inviteeEmail: String, caregiver: Bool = false) {
        self.inviteeEmail = inviteeEmail
        self.caregiver = caregiver
    }
}

struct ConnectionTypeUpdate: Encodable {
    let caregiver: Bool
}

struct CaregiverConnectionChild: Decodable, Identifiable, Sendable {
    let userId: UUID
    let displayName: String?
    let familyId: UUID
    let familyName: String
    let connectionId: UUID

    var id: UUID { userId }
}
