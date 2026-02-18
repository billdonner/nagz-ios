import AppIntents
import Foundation

struct CreateNagIntent: AppIntent {
    static var title: LocalizedStringResource { "Create a Nag" }
    static var description: IntentDescription { "Create a new nag for a family member." }

    @Parameter(title: "Recipient")
    var recipient: FamilyMemberEntity

    @Parameter(title: "Category")
    var category: NagCategoryAppEnum

    @Parameter(title: "Due At")
    var dueAt: Date

    @Parameter(title: "Description")
    var nagDescription: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = try await IntentServiceContainer.requireAuth()
        let familyId = try IntentServiceContainer.currentFamilyId()
        guard let recipientId = UUID(uuidString: recipient.id) else {
            throw NagzIntentError.notLoggedIn
        }

        let nag = NagCreate(
            familyId: familyId,
            recipientId: recipientId,
            dueAt: dueAt,
            category: category.nagCategory,
            doneDefinition: .binaryCheck,
            description: nagDescription
        )

        let _: NagResponse = try await api.request(.createNag(nag))

        let dueDateString = dueAt.formatted(date: .abbreviated, time: .shortened)
        return .result(dialog: "Created \(category.rawValue) nag for \(recipient.displayName), due \(dueDateString).")
    }
}
