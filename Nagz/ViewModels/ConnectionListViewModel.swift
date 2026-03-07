import Foundation
import Observation

@Observable
@MainActor
final class ConnectionListViewModel {
    var connections: [ConnectionResponse] = []
    var pendingInvites: [ConnectionResponse] = []
    var sentInvites: [ConnectionResponse] = []
    var connectionStats: [UUID: ConnectionNagStats] = [:]
    var loadState: LoadState<Void> = .idle
    var errorMessage: String?
    var inviteEmail = ""
    var isInviting = false
    var inviteError: String?
    var inviteSuccess = false
    var invitedEmail = ""

    let apiClient: APIClient
    var currentUserId: UUID?

    struct ConnectionNagStats {
        var sent: Int = 0
        var received: Int = 0
        var openCount: Int = 0
        var completedCount: Int = 0
        var overdueCount: Int = 0
        var missedCount: Int = 0
        var onTimeCount: Int = 0       // completed before or at dueAt
        var totalNags: Int = 0

        /// Completion rate as a percentage (completed / (completed + missed))
        var completionRate: Int? {
            let total = completedCount + missedCount
            guard total > 0 else { return nil }
            return Int(Double(completedCount) / Double(total) * 100)
        }

        /// On-time rate as a percentage (onTime / completed)
        var onTimeRate: Int? {
            guard completedCount > 0 else { return nil }
            return Int(Double(onTimeCount) / Double(completedCount) * 100)
        }

        /// Reliability label based on blended score: 60% completion + 40% on-time
        var reliabilityLabel: String? {
            guard let cr = completionRate else { return nil }
            let otr = onTimeRate ?? 0
            let score = (cr * 60 + otr * 40) / 100
            if score >= 80 { return "Reliable" }
            if score >= 60 { return "Usually OK" }
            if score >= 40 { return "Sometimes Late" }
            return "Needs Work"
        }

        /// Color for the reliability badge
        var reliabilityColor: String {
            guard let cr = completionRate else { return "gray" }
            let otr = onTimeRate ?? 0
            let score = (cr * 60 + otr * 40) / 100
            if score >= 80 { return "green" }
            if score >= 60 { return "blue" }
            if score >= 40 { return "orange" }
            return "red"
        }
    }

    init(apiClient: APIClient, currentUserId: UUID? = nil) {
        self.apiClient = apiClient
        self.currentUserId = currentUserId
    }

    func loadConnections() async {
        guard !loadState.isLoading else { return }
        loadState = .loading
        errorMessage = nil
        do {
            async let activeResult: PaginatedResponse<ConnectionResponse> = apiClient.request(
                .listConnections(status: .active)
            )
            async let pendingResult: PaginatedResponse<ConnectionResponse> = apiClient.request(
                .listPendingInvites()
            )
            async let allPendingResult: PaginatedResponse<ConnectionResponse> = apiClient.request(
                .listConnections(status: .pending)
            )
            let (active, pending, allPending) = try await (activeResult, pendingResult, allPendingResult)
            connections = active.items
            pendingInvites = pending.items
            // Sent invites = all pending minus inbound (those addressed to me)
            let inboundIds = Set(pending.items.map(\.id))
            sentInvites = allPending.items.filter { !inboundIds.contains($0.id) }
            // Load nag stats per active connection
            await loadConnectionStats(connections: active.items)
            loadState = .success(())
        } catch let error as APIError {
            loadState = .failure(error)
            errorMessage = error.errorDescription
        } catch {
            loadState = .failure(error)
            errorMessage = error.localizedDescription
        }
    }

    private func loadConnectionStats(connections: [ConnectionResponse]) async {
        let myUserId = self.currentUserId
        await withTaskGroup(of: (UUID, ConnectionNagStats).self) { group in
            for conn in connections {
                group.addTask {
                    do {
                        let resp: PaginatedResponse<NagResponse> = try await self.apiClient.request(
                            .listNags(connectionId: conn.id, limit: 200)
                        )
                        var stats = ConnectionNagStats()
                        let now = Date()
                        stats.totalNags = resp.items.count
                        for nag in resp.items {
                            if nag.creatorId == myUserId {
                                stats.sent += 1
                            } else {
                                stats.received += 1
                            }
                            if nag.status == .open {
                                stats.openCount += 1
                                if nag.dueAt < now {
                                    stats.overdueCount += 1
                                }
                            }
                            if nag.status == .completed {
                                stats.completedCount += 1
                                if let completedAt = nag.completedAt, completedAt <= nag.dueAt {
                                    stats.onTimeCount += 1
                                }
                            }
                            if nag.status == .missed { stats.missedCount += 1 }
                        }
                        return (conn.id, stats)
                    } catch {
                        return (conn.id, ConnectionNagStats())
                    }
                }
            }
            for await (id, stats) in group {
                connectionStats[id] = stats
            }
        }
    }

    func sendInvite() async {
        guard !inviteEmail.isEmpty else { return }
        isInviting = true
        inviteError = nil
        inviteSuccess = false
        do {
            let _: ConnectionResponse = try await apiClient.request(
                .inviteConnection(email: inviteEmail)
            )
            invitedEmail = inviteEmail
            inviteEmail = ""
            inviteSuccess = true
            await loadConnections()
        } catch let error as APIError {
            inviteError = error.errorDescription
        } catch {
            inviteError = error.localizedDescription
        }
        isInviting = false
    }

    func accept(id: UUID) async {
        do {
            let _: ConnectionResponse = try await apiClient.request(.acceptConnection(id: id))
            await loadConnections()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func decline(id: UUID) async {
        do {
            let _: ConnectionResponse = try await apiClient.request(.declineConnection(id: id))
            await loadConnections()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revoke(id: UUID) async {
        do {
            let _: ConnectionResponse = try await apiClient.request(.revokeConnection(id: id))
            await loadConnections()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleType(id: UUID, currentCaregiver: Bool) async {
        do {
            let _: ConnectionResponse = try await apiClient.request(
                .updateConnectionType(id: id, caregiver: !currentCaregiver)
            )
            await loadConnections()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
