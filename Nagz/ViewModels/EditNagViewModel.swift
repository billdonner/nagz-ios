import Foundation
import Observation

@Observable
@MainActor
final class EditNagViewModel {
    var dueAt: Date
    var category: NagCategory
    var doneDefinition: DoneDefinition
    var isUpdating = false
    var errorMessage: String?
    var didSave = false

    private let apiClient: APIClient
    private let nagId: UUID
    private let originalDueAt: Date
    private let originalCategory: NagCategory
    private let originalDoneDefinition: DoneDefinition

    init(apiClient: APIClient, nag: NagResponse) {
        self.apiClient = apiClient
        self.nagId = nag.id
        self.dueAt = nag.dueAt
        self.category = nag.category
        self.doneDefinition = nag.doneDefinition
        self.originalDueAt = nag.dueAt
        self.originalCategory = nag.category
        self.originalDoneDefinition = nag.doneDefinition
    }

    var hasChanges: Bool {
        dueAt != originalDueAt || category != originalCategory || doneDefinition != originalDoneDefinition
    }

    func save() async {
        guard hasChanges else { return }
        isUpdating = true
        errorMessage = nil
        do {
            let update = NagUpdate(
                dueAt: dueAt != originalDueAt ? dueAt : nil,
                category: category != originalCategory ? category : nil,
                doneDefinition: doneDefinition != originalDoneDefinition ? doneDefinition : nil
            )
            let _: NagResponse = try await apiClient.request(.updateNag(nagId: nagId, update: update))
            didSave = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }
}
