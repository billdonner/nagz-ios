import Foundation
import Observation

@Observable
@MainActor
final class NagDetailViewModel {
    var nag: NagResponse?
    var escalation: EscalationResponse?
    var isLoading = false
    var isUpdating = false
    var errorMessage: String?

    private let apiClient: APIClient
    private let nagId: UUID

    init(apiClient: APIClient, nagId: UUID) {
        self.apiClient = apiClient
        self.nagId = nagId
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedNag: NagResponse = try await apiClient.request(.getNag(id: nagId))
            nag = loadedNag
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            isLoading = false
            return
        }

        // Escalation may not exist yet, that's OK
        do {
            let loadedEscalation: EscalationResponse = try await apiClient.request(.getEscalation(nagId: nagId))
            escalation = loadedEscalation
        } catch {
            // Ignore escalation errors
        }

        isLoading = false
    }

    func markComplete(note: String? = nil) async {
        isUpdating = true
        errorMessage = nil
        do {
            let updated: NagResponse = try await apiClient.request(
                .updateNagStatus(nagId: nagId, status: .completed, note: note)
            )
            nag = updated
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }
}
