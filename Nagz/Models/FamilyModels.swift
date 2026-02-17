import Foundation

struct FamilyResponse: Decodable, Identifiable, Sendable {
    let familyId: UUID
    let name: String
    let inviteCode: String
    let createdAt: Date

    var id: UUID { familyId }
}

struct FamilyCreate: Encodable {
    let name: String
}

struct JoinRequest: Encodable {
    let inviteCode: String
}

struct MemberResponse: Decodable, Sendable {
    let userId: UUID
    let familyId: UUID
    let role: FamilyRole
    let status: MembershipStatus
    let joinedAt: Date
}

struct MemberDetail: Decodable, Identifiable, Sendable {
    let userId: UUID
    let displayName: String?
    let familyId: UUID
    let role: FamilyRole
    let status: MembershipStatus
    let joinedAt: Date

    var id: UUID { userId }
}

struct MemberAdd: Encodable {
    let userId: UUID
    let role: FamilyRole
}

struct MemberCreateAndAdd: Encodable {
    let displayName: String
    let role: FamilyRole
}
