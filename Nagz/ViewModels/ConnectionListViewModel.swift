import Foundation
import Observation

@Observable
@MainActor
final class ConnectionListViewModel {
    var connections: [ConnectionResponse] = []
    var pendingInvites: [ConnectionResponse] = []
    var sentInvites: [ConnectionResponse] = []
    var isLoading = false
    var errorMessage: String?
    var inviteEmail = ""
    var isInviting = false
    var inviteError: String?
    var inviteSuccess = false
    var invitedEmail = ""

    let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadConnections() async {
        isLoading = true
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
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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

    func toggleTrust(id: UUID, currentTrusted: Bool) async {
        do {
            let _: ConnectionResponse = try await apiClient.request(
                .updateConnectionTrust(id: id, trusted: !currentTrusted)
            )
            await loadConnections()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
