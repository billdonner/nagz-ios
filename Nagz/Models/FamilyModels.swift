import Foundation

struct FamilyResponse: Decodable, Identifiable, Sendable {
    let familyId: UUID
    let name: String
    let inviteCode: String
    let childCode: String?
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
    let hasChildLogin: Bool?

    var id: UUID { userId }
}

struct MemberAdd: Encodable {
    let userId: UUID
    let role: FamilyRole
}

struct MemberCreateAndAdd: Encodable {
    let displayName: String
    let role: FamilyRole
    let username: String?
    let pin: String?
}

struct ChildCredentialsSet: Encodable {
    let username: String
    let pin: String
}

struct PinChangeRequest: Encodable {
    let currentPin: String
    let newPin: String
}

struct ChildSettingsResponse: Decodable, Sendable {
    let childUserId: UUID
    let familyId: UUID
    let canSnooze: Bool
    let maxSnoozesPerDay: Int
    let canSubmitExcuses: Bool
    let quietHoursStart: String?
    let quietHoursEnd: String?
}

struct ChildSettingsUpdate: Encodable {
    let canSnooze: Bool?
    let maxSnoozesPerDay: Int?
    let canSubmitExcuses: Bool?
    let quietHoursStart: String?
    let quietHoursEnd: String?
}
