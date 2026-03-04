import Foundation

struct NagResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let familyId: UUID?
    let connectionId: UUID?
    let creatorId: UUID
    let recipientId: UUID
    let creatorDisplayName: String?
    let recipientDisplayName: String?
    let dueAt: Date
    let category: NagCategory
    let doneDefinition: DoneDefinition
    let description: String?
    let strategyTemplate: StrategyTemplate
    let recurrence: Recurrence?
    let parentNagId: UUID?
    let status: NagStatus
    let createdAt: Date
    let completedAt: Date?
    let committedAt: Date?
    let recipientDismissedAt: Date?
}

struct NagCreate: Encodable {
    let familyId: UUID?
    let connectionId: UUID?
    let recipientId: UUID
    let dueAt: Date
    let category: NagCategory
    let doneDefinition: DoneDefinition
    let description: String?
    let strategyTemplate: StrategyTemplate
    let recurrence: Recurrence?

    init(
        familyId: UUID? = nil,
        connectionId: UUID? = nil,
        recipientId: UUID,
        dueAt: Date,
        category: NagCategory,
        doneDefinition: DoneDefinition,
        description: String? = nil,
        strategyTemplate: StrategyTemplate = .friendlyReminder,
        recurrence: Recurrence? = nil
    ) {
        self.familyId = familyId
        self.connectionId = connectionId
        self.recipientId = recipientId
        self.dueAt = dueAt
        self.category = category
        self.doneDefinition = doneDefinition
        self.description = description
        self.strategyTemplate = strategyTemplate
        self.recurrence = recurrence
    }
}

struct NagStatusUpdate: Encodable {
    let status: NagStatus
    let note: String?

    init(status: NagStatus, note: String? = nil) {
        self.status = status
        self.note = note
    }
}

struct NagUpdate: Encodable {
    let dueAt: Date?
    let category: NagCategory?
    let doneDefinition: DoneDefinition?
    let committedAt: Date?
    let clearCommittedAt: Bool

    init(dueAt: Date? = nil, category: NagCategory? = nil, doneDefinition: DoneDefinition? = nil, committedAt: Date? = nil, clearCommittedAt: Bool = false) {
        self.dueAt = dueAt
        self.category = category
        self.doneDefinition = doneDefinition
        self.committedAt = committedAt
        self.clearCommittedAt = clearCommittedAt
    }

    private enum CodingKeys: String, CodingKey {
        case dueAt, category, doneDefinition, committedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(dueAt, forKey: .dueAt)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(doneDefinition, forKey: .doneDefinition)
        if clearCommittedAt {
            try container.encodeNil(forKey: .committedAt)
        } else {
            try container.encodeIfPresent(committedAt, forKey: .committedAt)
        }
    }
}
