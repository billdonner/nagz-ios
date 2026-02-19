import AppIntents
import Foundation

struct CompleteNagIntent: AppIntent {
    static var title: LocalizedStringResource { "Complete a Nag" }
    static var description: IntentDescription { "Mark a nag as completed." }

    @Parameter(title: "Nag")
    var nag: NagEntity

    @Parameter(title: "Note")
    var note: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = try await IntentServiceContainer.requireAuth()
        guard let nagId = UUID(uuidString: nag.id) else {
            throw NagzIntentError.invalidNagId
        }

        try await api.requestVoid(.updateNagStatus(nagId: nagId, status: .completed, note: note))

        return .result(dialog: "Done! Marked \(nag.category) nag as completed.")
    }
}
