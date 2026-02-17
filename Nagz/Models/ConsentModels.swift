import Foundation

struct ConsentResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let familyIdNullable: UUID?
    let consentType: ConsentType
}

struct ConsentCreate: Encodable {
    let familyId: UUID?
    let consentType: ConsentType

    init(familyId: UUID? = nil, consentType: ConsentType) {
        self.familyId = familyId
        self.consentType = consentType
    }
}

struct ConsentUpdate: Encodable {
    let revoked: Bool
}
