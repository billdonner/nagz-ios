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

    // Custom decoder: tolerates old cached responses that used "trusted" instead of "caregiver"
    private enum CodingKeys: String, CodingKey {
        case id, inviterId, inviteeId, inviteeEmail, status
        case caregiver, trusted   // accept both spellings
        case createdAt, respondedAt, otherPartyEmail, otherPartyDisplayName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        inviterId = try c.decode(UUID.self, forKey: .inviterId)
        inviteeId = try c.decodeIfPresent(UUID.self, forKey: .inviteeId)
        inviteeEmail = try c.decode(String.self, forKey: .inviteeEmail)
        status = try c.decode(ConnectionStatus.self, forKey: .status)
        // Try "caregiver" first (current API), fall back to "trusted" (legacy cache), then default false
        caregiver = (try? c.decode(Bool.self, forKey: .caregiver))
                 ?? (try? c.decode(Bool.self, forKey: .trusted))
                 ?? false
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        respondedAt = try c.decodeIfPresent(Date.self, forKey: .respondedAt)
        otherPartyEmail = try c.decodeIfPresent(String.self, forKey: .otherPartyEmail)
        otherPartyDisplayName = try c.decodeIfPresent(String.self, forKey: .otherPartyDisplayName)
    }
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
