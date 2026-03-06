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
    let attachmentUrls: [String]

    init(id: UUID, familyId: UUID? = nil, connectionId: UUID? = nil, creatorId: UUID, recipientId: UUID, creatorDisplayName: String? = nil, recipientDisplayName: String? = nil, dueAt: Date, category: NagCategory, doneDefinition: DoneDefinition, description: String? = nil, strategyTemplate: StrategyTemplate, recurrence: Recurrence? = nil, parentNagId: UUID? = nil, status: NagStatus, createdAt: Date, completedAt: Date? = nil, committedAt: Date? = nil, recipientDismissedAt: Date? = nil, attachmentUrls: [String] = []) {
        self.id = id; self.familyId = familyId; self.connectionId = connectionId
        self.creatorId = creatorId; self.recipientId = recipientId
        self.creatorDisplayName = creatorDisplayName; self.recipientDisplayName = recipientDisplayName
        self.dueAt = dueAt; self.category = category; self.doneDefinition = doneDefinition
        self.description = description; self.strategyTemplate = strategyTemplate
        self.recurrence = recurrence; self.parentNagId = parentNagId; self.status = status
        self.createdAt = createdAt; self.completedAt = completedAt; self.committedAt = committedAt
        self.recipientDismissedAt = recipientDismissedAt; self.attachmentUrls = attachmentUrls
    }

    private enum CodingKeys: String, CodingKey {
        case id, familyId, connectionId, creatorId, recipientId
        case creatorDisplayName, recipientDisplayName
        case dueAt, category, doneDefinition, description, strategyTemplate
        case recurrence, parentNagId, status, createdAt, completedAt, committedAt
        case recipientDismissedAt, attachmentUrls
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        familyId = try c.decodeIfPresent(UUID.self, forKey: .familyId)
        connectionId = try c.decodeIfPresent(UUID.self, forKey: .connectionId)
        creatorId = try c.decode(UUID.self, forKey: .creatorId)
        recipientId = try c.decode(UUID.self, forKey: .recipientId)
        creatorDisplayName = try c.decodeIfPresent(String.self, forKey: .creatorDisplayName)
        recipientDisplayName = try c.decodeIfPresent(String.self, forKey: .recipientDisplayName)
        dueAt = try c.decode(Date.self, forKey: .dueAt)
        category = try c.decode(NagCategory.self, forKey: .category)
        doneDefinition = try c.decode(DoneDefinition.self, forKey: .doneDefinition)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        strategyTemplate = try c.decode(StrategyTemplate.self, forKey: .strategyTemplate)
        recurrence = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence)
        parentNagId = try c.decodeIfPresent(UUID.self, forKey: .parentNagId)
        status = try c.decode(NagStatus.self, forKey: .status)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        committedAt = try c.decodeIfPresent(Date.self, forKey: .committedAt)
        recipientDismissedAt = try c.decodeIfPresent(Date.self, forKey: .recipientDismissedAt)
        attachmentUrls = try c.decodeIfPresent([String].self, forKey: .attachmentUrls) ?? []
    }
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
    let attachmentIds: [String]

    init(
        familyId: UUID? = nil,
        connectionId: UUID? = nil,
        recipientId: UUID,
        dueAt: Date,
        category: NagCategory,
        doneDefinition: DoneDefinition,
        description: String? = nil,
        strategyTemplate: StrategyTemplate = .friendlyReminder,
        recurrence: Recurrence? = nil,
        attachmentIds: [String] = []
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
        self.attachmentIds = attachmentIds
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
    let description: String?

    init(dueAt: Date? = nil, category: NagCategory? = nil, doneDefinition: DoneDefinition? = nil, committedAt: Date? = nil, clearCommittedAt: Bool = false, description: String? = nil) {
        self.dueAt = dueAt
        self.category = category
        self.doneDefinition = doneDefinition
        self.committedAt = committedAt
        self.clearCommittedAt = clearCommittedAt
        self.description = description
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
