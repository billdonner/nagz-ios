import Foundation

struct NagResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let familyId: UUID?
    let connectionId: UUID?
    let creatorId: UUID
    let recipientId: UUID
    let dueAt: Date
    let category: NagCategory
    let doneDefinition: DoneDefinition
    let description: String?
    let strategyTemplate: StrategyTemplate
    let recurrence: Recurrence?
    let status: NagStatus
    let createdAt: Date
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

    init(dueAt: Date? = nil, category: NagCategory? = nil, doneDefinition: DoneDefinition? = nil) {
        self.dueAt = dueAt
        self.category = category
        self.doneDefinition = doneDefinition
    }
}
