import Foundation
import GRDB

/// Manages the local GRDB SQLite cache for offline AI and sync.
actor DatabaseManager {
    private let dbPool: DatabasePool

    /// Opens (or creates) the local cache database.
    init(path: String? = nil) throws {
        let url: URL
        if let path {
            url = URL(fileURLWithPath: path)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("NagzCache", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("cache.sqlite")
        }

        var config = Configuration()
        config.foreignKeysEnabled = true

        dbPool = try DatabasePool(path: url.path, configuration: config)
        try Self.makeMigrator().migrate(dbPool)
    }

    /// Temporary on-disk database for tests (DatabasePool requires a real file for WAL mode).
    static func inMemory() throws -> DatabaseManager {
        let tmpDir = FileManager.default.temporaryDirectory
        let path = tmpDir.appendingPathComponent("nagz-test-\(UUID().uuidString).sqlite").path
        return try DatabaseManager(path: path)
    }

    var reader: DatabaseReader { dbPool }
    var writer: DatabaseWriter { dbPool }

    // MARK: - Migrations

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_cache_tables") { db in
            try db.create(table: "cached_nags") { t in
                t.primaryKey("id", .text).notNull()
                t.column("familyId", .text).notNull()
                t.column("creatorId", .text).notNull()
                t.column("recipientId", .text).notNull()
                t.column("dueAt", .datetime).notNull()
                t.column("category", .text).notNull()
                t.column("doneDefinition", .text).notNull()
                t.column("description", .text)
                t.column("status", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("syncedAt", .datetime).notNull()
            }

            try db.create(table: "cached_nag_events") { t in
                t.primaryKey("id", .text).notNull()
                t.column("nagId", .text).notNull()
                t.column("eventType", .text).notNull()
                t.column("actorId", .text).notNull()
                t.column("at", .datetime).notNull()
                t.column("payload", .text).notNull().defaults(to: "{}")
                t.column("syncedAt", .datetime).notNull()
            }

            try db.create(table: "cached_ai_mediation_events") { t in
                t.primaryKey("id", .text).notNull()
                t.column("nagId", .text).notNull()
                t.column("promptType", .text).notNull()
                t.column("tone", .text).notNull()
                t.column("summary", .text).notNull()
                t.column("at", .datetime).notNull()
                t.column("syncedAt", .datetime).notNull()
            }

            try db.create(table: "cached_gamification_events") { t in
                t.primaryKey("id", .text).notNull()
                t.column("familyId", .text).notNull()
                t.column("userId", .text).notNull()
                t.column("eventType", .text).notNull()
                t.column("deltaPoints", .integer).notNull().defaults(to: 0)
                t.column("streakDelta", .integer).notNull().defaults(to: 0)
                t.column("at", .datetime).notNull()
                t.column("syncedAt", .datetime).notNull()
            }

            try db.create(table: "cached_preferences") { t in
                t.primaryKey("userId", .text).notNull()
                t.column("familyId", .text).notNull()
                t.column("prefsJson", .text).notNull()
                t.column("syncedAt", .datetime).notNull()
            }

            try db.create(table: "sync_metadata") { t in
                t.primaryKey("entity", .text).notNull()
                t.column("lastSyncAt", .datetime).notNull()
            }
        }

        return migrator
    }

    // MARK: - Smart Defaults

    /// Returns the most frequently used category and doneDefinition for a creator→recipient pair.
    func nagDefaults(creatorId: String, recipientId: String) throws -> (category: String?, doneDefinition: String?) {
        try dbPool.read { db in
            let rows = try CachedNag
                .filter(Column("creatorId") == creatorId)
                .filter(Column("recipientId") == recipientId)
                .fetchAll(db)

            guard !rows.isEmpty else { return (nil, nil) }

            let catCounts = Dictionary(grouping: rows, by: \.category)
            let topCat = catCounts.max(by: { $0.value.count < $1.value.count })?.key

            let doneCounts = Dictionary(grouping: rows, by: \.doneDefinition)
            let topDone = doneCounts.max(by: { $0.value.count < $1.value.count })?.key

            return (topCat, topDone)
        }
    }

    // MARK: - Cleanup

    /// Remove events older than the retention period.
    func pruneStaleData() async throws {
        let eventCutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let nagCutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        try await writer.write { db in
            try db.execute(sql: "DELETE FROM cached_nag_events WHERE at < ?", arguments: [eventCutoff])
            try db.execute(sql: "DELETE FROM cached_ai_mediation_events WHERE at < ?", arguments: [eventCutoff])
            try db.execute(sql: "DELETE FROM cached_gamification_events WHERE at < ?", arguments: [eventCutoff])
            try db.execute(
                sql: "DELETE FROM cached_nags WHERE status != 'open' AND createdAt < ?",
                arguments: [nagCutoff]
            )
        }
    }

    /// Clear all cached data (e.g. on logout).
    func clearAll() async throws {
        try await writer.write { db in
            try db.execute(sql: "DELETE FROM cached_nags")
            try db.execute(sql: "DELETE FROM cached_nag_events")
            try db.execute(sql: "DELETE FROM cached_ai_mediation_events")
            try db.execute(sql: "DELETE FROM cached_gamification_events")
            try db.execute(sql: "DELETE FROM cached_preferences")
            try db.execute(sql: "DELETE FROM sync_metadata")
        }
    }
}
