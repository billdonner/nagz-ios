import Foundation
import Observation

@Observable
@MainActor
final class ConnectionListViewModel {
    var connections: [ConnectionResponse] = []
    var pendingInvites: [ConnectionResponse] = []
    var isLoading = false
    var errorMessage: String?
    var inviteEmail = ""
    var isInviting = false
    var inviteError: String?
    var inviteSuccess = false

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
            let (active, pending) = try await (activeResult, pendingResult)
            connections = active.items
            pendingInvites = pending.items
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
}
