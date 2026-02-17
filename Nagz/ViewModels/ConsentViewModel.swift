import Foundation
import Observation

@Observable
@MainActor
final class ConsentViewModel {
    var consents: [ConsentResponse] = []
    var isLoading = false
    var isUpdating = false
    var errorMessage: String?

    private let apiClient: APIClient
    private let familyId: UUID

    init(apiClient: APIClient, familyId: UUID) {
        self.apiClient = apiClient
        self.familyId = familyId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: PaginatedResponse<ConsentResponse> = try await apiClient.request(
                .listConsents(familyId: familyId)
            )
            consents = response.items
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func hasConsent(for type: ConsentType) -> Bool {
        consents.contains { $0.consentType == type }
    }

    func grantConsent(_ type: ConsentType) async {
        isUpdating = true
        errorMessage = nil
        do {
            let _: ConsentResponse = try await apiClient.request(
                .grantConsent(familyId: familyId, consentType: type)
            )
            await load()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }

    func revokeConsent(_ consent: ConsentResponse) async {
        isUpdating = true
        errorMessage = nil
        do {
            let _: ConsentResponse = try await apiClient.request(
                .revokeConsent(consentId: consent.id)
            )
            await load()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }
}
