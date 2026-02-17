import Foundation

struct PolicyResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let familyId: UUID
    let owners: [UUID]
    let strategyTemplate: StrategyTemplate
    let constraints: [String: AnyCodableValue]
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, owners, status, constraints
        case familyId = "family_id"
        case strategyTemplate = "strategy_template"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        familyId = try container.decode(UUID.self, forKey: .familyId)
        strategyTemplate = try container.decode(StrategyTemplate.self, forKey: .strategyTemplate)
        status = try container.decode(String.self, forKey: .status)
        constraints = (try? container.decode([String: AnyCodableValue].self, forKey: .constraints)) ?? [:]

        // owners can be [UUID] or [String]
        if let uuids = try? container.decode([UUID].self, forKey: .owners) {
            owners = uuids
        } else if let strings = try? container.decode([String].self, forKey: .owners) {
            owners = strings.compactMap { UUID(uuidString: $0) }
        } else {
            owners = []
        }
    }
}

struct PolicyUpdate: Encodable {
    let strategyTemplate: StrategyTemplate?
    let constraints: [String: AnyCodableValue]?
    let owners: [UUID]?
}

struct ApprovalCreate: Encodable {
    let comment: String?
}

struct ApprovalResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let policyId: UUID
    let approverId: UUID
    let approvedAt: Date
    let comment: String?
}
