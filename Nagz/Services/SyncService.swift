import Foundation
import GRDB

/// Polls the server for incremental event data and writes to the local GRDB cache.
actor SyncService {
    private let apiClient: APIClient
    private let db: DatabaseManager
    private let syncInterval: TimeInterval
    private var syncTask: Task<Void, Never>?

    init(apiClient: APIClient, db: DatabaseManager, syncInterval: TimeInterval = 300) {
        self.apiClient = apiClient
        self.db = db
        self.syncInterval = syncInterval
    }

    /// Start periodic background sync for a family.
    func startPeriodicSync(familyId: UUID) {
        stopSync()
        syncTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await self.sync(familyId: familyId)
                } catch {
                    // Log but don't crash — sync is best-effort
                }
                try? await Task.sleep(for: .seconds(self.syncInterval))
            }
        }
    }

    func stopSync() {
        syncTask?.cancel()
        syncTask = nil
    }

    /// One-shot sync for a family.
    func sync(familyId: UUID) async throws {
        let since = try await lastSyncTime(entity: "all")
        let response: SyncResponse = try await apiClient.request(
            .syncEvents(familyId: familyId, since: since)
        )

        let now = Date()
        let writer = await db.writer

        try await writer.write { db in
            // Upsert nags
            for nag in response.nags {
                let record = CachedNag(
                    id: nag.id.uuidString,
                    familyId: nag.familyId.uuidString,
                    creatorId: nag.creatorId.uuidString,
                    recipientId: nag.recipientId.uuidString,
                    dueAt: nag.dueAt,
                    category: nag.category,
                    doneDefinition: nag.doneDefinition,
                    description: nag.description,
                    status: nag.status,
                    createdAt: nag.createdAt,
                    syncedAt: now
                )
                try record.save(db)
            }

            // Upsert nag events
            for event in response.nagEvents {
                let payload: String
                if let p = event.payload, !p.isEmpty,
                   let data = try? JSONSerialization.data(withJSONObject: p) {
                    payload = String(data: data, encoding: .utf8) ?? "{}"
                } else {
                    payload = "{}"
                }
                let record = CachedNagEvent(
                    id: event.id.uuidString,
                    nagId: event.nagId.uuidString,
                    eventType: event.eventType,
                    actorId: event.actorId.uuidString,
                    at: event.at,
                    payload: payload,
                    syncedAt: now
                )
                try record.save(db)
            }

            // Upsert AI mediation events
            for event in response.aiMediationEvents {
                let record = CachedAIMediationEvent(
                    id: event.id.uuidString,
                    nagId: event.nagId.uuidString,
                    promptType: event.promptType,
                    tone: event.tone,
                    summary: event.summary,
                    at: event.at,
                    syncedAt: now
                )
                try record.save(db)
            }

            // Upsert gamification events
            for event in response.gamificationEvents {
                let record = CachedGamificationEvent(
                    id: event.id.uuidString,
                    familyId: event.familyId.uuidString,
                    userId: event.userId.uuidString,
                    eventType: event.eventType,
                    deltaPoints: event.deltaPoints,
                    streakDelta: event.streakDelta,
                    at: event.at,
                    syncedAt: now
                )
                try record.save(db)
            }

            // Update sync metadata
            let meta = SyncMetadata(entity: "all", lastSyncAt: response.serverTime)
            try meta.save(db)
        }
    }

    /// Clear local cache (e.g. on logout).
    func clearCache() async throws {
        try await db.clearAll()
    }

    // MARK: - Private

    private func lastSyncTime(entity: String) async throws -> Date? {
        let reader = await db.reader
        return try await reader.read { db in
            try SyncMetadata
                .filter(Column("entity") == entity)
                .fetchOne(db)?
                .lastSyncAt
        }
    }
}
