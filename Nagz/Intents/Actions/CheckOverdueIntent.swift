import AppIntents
import Foundation

struct CheckOverdueIntent: AppIntent {
    static var title: LocalizedStringResource { "Check Overdue Nags" }
    static var description: IntentDescription { "Check if any nags are overdue." }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = try await IntentServiceContainer.requireAuth()
        let familyId = try IntentServiceContainer.currentFamilyId()

        let response: PaginatedResponse<NagResponse> = try await api.request(
            .listNags(familyId: familyId, status: .open)
        )

        let now = Date()
        let overdue = response.items.filter { $0.dueAt < now }

        if overdue.isEmpty {
            return .result(dialog: "No overdue nags. You're all caught up!")
        }

        let categories = overdue.map { $0.category.displayName }.joined(separator: ", ")
        let count = overdue.count
        return .result(dialog: "\(count) overdue: \(categories).")
    }
}
