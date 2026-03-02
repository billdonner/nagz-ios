import AppIntents
import Foundation

struct QuickAddNagIntent: AppIntent {
    static var title: LocalizedStringResource { "Quick Remind Me" }
    static var description: IntentDescription { "Quickly create a self-reminder with just a description and time." }

    @Parameter(title: "What to remember")
    var nagDescription: String

    @Parameter(title: "Due in minutes", default: 60)
    var minutesUntilDue: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = try await IntentServiceContainer.requireAuth()
        let userId = try IntentServiceContainer.currentUserId()
        let familyId = try? IntentServiceContainer.currentFamilyId()

        let dueAt = Date().addingTimeInterval(Double(minutesUntilDue) * 60)
        let nag = NagCreate(
            familyId: familyId,
            recipientId: userId,
            dueAt: dueAt,
            category: .other,
            doneDefinition: .binaryCheck,
            description: nagDescription
        )

        let _: NagResponse = try await api.request(.createNag(nag))

        let dueString = dueAt.formatted(date: .omitted, time: .shortened)
        return .result(dialog: "Got it! I'll nag you about \(nagDescription) at \(dueString).")
    }
}
