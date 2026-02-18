import Foundation
import GRDB

// MARK: - Cached Nag

struct CachedNag: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "cached_nags"

    var id: String // UUID as string
    var familyId: String
    var creatorId: String
    var recipientId: String
    var dueAt: Date
    var category: String
    var doneDefinition: String
    var description: String?
    var status: String
    var createdAt: Date
    var syncedAt: Date
}

// MARK: - Cached Nag Event

struct CachedNagEvent: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "cached_nag_events"

    var id: String
    var nagId: String
    var eventType: String
    var actorId: String
    var at: Date
    var payload: String
    var syncedAt: Date
}

// MARK: - Cached AI Mediation Event

struct CachedAIMediationEvent: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "cached_ai_mediation_events"

    var id: String
    var nagId: String
    var promptType: String
    var tone: String
    var summary: String
    var at: Date
    var syncedAt: Date
}

// MARK: - Cached Gamification Event

struct CachedGamificationEvent: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "cached_gamification_events"

    var id: String
    var familyId: String
    var userId: String
    var eventType: String
    var deltaPoints: Int
    var streakDelta: Int
    var at: Date
    var syncedAt: Date
}

// MARK: - Cached Preferences

struct CachedPreferences: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "cached_preferences"

    var userId: String
    var familyId: String
    var prefsJson: String
    var syncedAt: Date
}

// MARK: - Sync Metadata

struct SyncMetadata: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "sync_metadata"

    var entity: String
    var lastSyncAt: Date
}
