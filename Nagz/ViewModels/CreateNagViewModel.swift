import Foundation
import Observation

@Observable
@MainActor
final class CreateNagViewModel {
    var recipientId: UUID?
    var dueAt = Date().addingTimeInterval(3600)
    var category: NagCategory = .chores
    var doneDefinition: DoneDefinition = .ackOnly
    var description = ""
    var recurrence: Recurrence?
    var errorMessage: String?
    var isLoading = false
    var didCreate = false

    /// Set by CreateNagView when a recipient is selected
    var contextFamilyId: UUID?
    var contextConnectionId: UUID?

    private let apiClient: APIClient
    private let familyId: UUID?

    init(apiClient: APIClient, familyId: UUID?) {
        self.apiClient = apiClient
        self.familyId = familyId
        self.contextFamilyId = familyId
    }

    var isValid: Bool {
        recipientId != nil && dueAt > Date() && (contextFamilyId != nil || contextConnectionId != nil)
    }

    func createNag() async {
        guard let recipientId else { return }
        isLoading = true
        errorMessage = nil
        do {
            let nag = NagCreate(
                familyId: contextFamilyId,
                connectionId: contextConnectionId,
                recipientId: recipientId,
                dueAt: dueAt,
                category: category,
                doneDefinition: doneDefinition,
                description: description.isEmpty ? nil : description,
                recurrence: recurrence
            )
            let _: NagResponse = try await apiClient.request(.createNag(nag))
            await apiClient.invalidateCache(prefix: "/nags")
            didCreate = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
