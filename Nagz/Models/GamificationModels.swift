import Foundation

struct GamificationSummary: Decodable, Sendable {
    let familyId: UUID
    let userId: UUID
    let totalPoints: Int
    let currentStreak: Int
    let eventCount: Int
}

struct LeaderboardEntry: Decodable, Identifiable, Sendable {
    let userId: UUID
    let totalPoints: Int

    var id: UUID { userId }
}

struct LeaderboardResponse: Decodable, Sendable {
    let familyId: UUID
    let periodStart: Date
    let leaderboard: [LeaderboardEntry]
}

struct GamificationEventResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let familyId: UUID
    let userId: UUID
    let eventType: String
    let deltaPoints: Int
    let streakDelta: Int
    let at: Date
}

struct BadgeResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let familyId: UUID
    let badgeType: String
    let earnedAt: Date
}
