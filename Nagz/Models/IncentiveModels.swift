import Foundation

struct IncentiveRuleResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let familyId: UUID
    let version: Int
    let condition: [String: AnyCodableValue]
    let action: [String: AnyCodableValue]
    let approvalMode: IncentiveApprovalMode
    let status: String
}

struct IncentiveRuleCreate: Encodable {
    let familyId: UUID
    let condition: [String: AnyCodableValue]
    let action: [String: AnyCodableValue]
    let approvalMode: IncentiveApprovalMode

    init(
        familyId: UUID,
        condition: [String: AnyCodableValue],
        action: [String: AnyCodableValue],
        approvalMode: IncentiveApprovalMode = .auto
    ) {
        self.familyId = familyId
        self.condition = condition
        self.action = action
        self.approvalMode = approvalMode
    }
}

struct IncentiveRuleUpdate: Encodable {
    let condition: [String: AnyCodableValue]?
    let action: [String: AnyCodableValue]?
    let approvalMode: IncentiveApprovalMode?

    init(
        condition: [String: AnyCodableValue]? = nil,
        action: [String: AnyCodableValue]? = nil,
        approvalMode: IncentiveApprovalMode? = nil
    ) {
        self.condition = condition
        self.action = action
        self.approvalMode = approvalMode
    }
}

struct IncentiveEventResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let nagId: UUID
    let ruleId: UUID
    let actionType: String
    let approvedBy: UUID?
    let at: Date
}
