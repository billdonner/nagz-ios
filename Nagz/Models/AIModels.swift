import Foundation

// MARK: - Enums

enum AITone: String, Codable, Sendable {
    case neutral
    case supportive
    case firm
}

enum ExcuseCategory: String, Codable, Sendable {
    case forgot
    case timeConflict = "time_conflict"
    case unclearInstructions = "unclear_instructions"
    case lackingResources = "lacking_resources"
    case refused
    case other
}

// MARK: - Summarize Excuse

struct ExcuseSummaryRequest: Encodable, Sendable {
    let text: String
    let nagId: UUID
}

struct ExcuseSummaryResponse: Decodable, Sendable {
    let nagId: UUID
    let summary: String
    let category: ExcuseCategory
    let confidence: Double
}

// MARK: - Select Tone

struct ToneSelectRequest: Encodable, Sendable {
    let nagId: UUID
}

struct ToneSelectResponse: Decodable, Sendable {
    let nagId: UUID
    let tone: AITone
    let missCount7d: Int
    let streak: Int
    let reason: String
}

// MARK: - Coaching

struct CoachingRequest: Encodable, Sendable {
    let nagId: UUID
}

struct CoachingResponse: Decodable, Sendable {
    let nagId: UUID
    let tip: String
    let category: String
    let scenario: String
}

// MARK: - Patterns

struct InsightItem: Decodable, Sendable {
    let dayOfWeek: String
    let missCount: Int
}

struct PatternsResponse: Decodable, Sendable {
    let userId: UUID
    let familyId: UUID
    let insights: [InsightItem]
    let analyzedAt: Date
}

// MARK: - Digest

struct MemberSummary: Decodable, Sendable {
    let userId: UUID
    let displayName: String?
    let totalNags: Int
    let completed: Int
    let missed: Int
    let completionRate: Double
}

struct DigestTotals: Decodable, Sendable {
    let totalNags: Int
    let completed: Int
    let missed: Int
    let open: Int
    let completionRate: Double
}

struct DigestResponse: Decodable, Sendable {
    let familyId: UUID
    let periodStart: Date
    let periodEnd: Date
    let summaryText: String
    let memberSummaries: [MemberSummary]
    let totals: DigestTotals
}

// MARK: - Predict Completion

struct CompletionFactor: Decodable, Sendable {
    let name: String
    let value: Double
}

struct PredictCompletionResponse: Decodable, Sendable {
    let nagId: UUID
    let likelihood: Double
    let suggestedReminderTime: Date?
    let factors: [CompletionFactor]
}

// MARK: - Push Back

struct PushBackRequest: Encodable, Sendable {
    let nagId: UUID
}

struct PushBackResponse: Decodable, Sendable {
    let nagId: UUID
    let shouldPushBack: Bool
    let message: String?
    let tone: AITone?
    let reason: String
}

// MARK: - Sync Models

struct SyncResponse: Decodable, Sendable {
    let nags: [SyncedNag]
    let nagEvents: [SyncedNagEvent]
    let aiMediationEvents: [SyncedAIMediationEvent]
    let gamificationEvents: [SyncedGamificationEvent]
    let serverTime: Date
}

struct SyncedNag: Decodable, Sendable {
    let id: UUID
    let familyId: UUID
    let creatorId: UUID
    let recipientId: UUID
    let dueAt: Date
    let category: String
    let doneDefinition: String
    let description: String?
    let status: String
    let createdAt: Date
}

struct SyncedNagEvent: Decodable, Sendable {
    let id: UUID
    let nagId: UUID
    let eventType: String
    let actorId: UUID
    let at: Date
    let payload: [String: String]?
}

struct SyncedAIMediationEvent: Decodable, Sendable {
    let id: UUID
    let nagId: UUID
    let promptType: String
    let tone: String
    let summary: String
    let at: Date
}

struct SyncedGamificationEvent: Decodable, Sendable {
    let id: UUID
    let familyId: UUID
    let userId: UUID
    let eventType: String
    let deltaPoints: Int
    let streakDelta: Int
    let at: Date
}
