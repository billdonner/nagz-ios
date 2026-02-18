import AppIntents
import Foundation

struct SnoozeNagIntent: AppIntent {
    static var title: LocalizedStringResource { "Snooze a Nag" }
    static var description: IntentDescription { "Postpone a nag by a number of minutes." }

    @Parameter(title: "Nag")
    var nag: NagEntity

    @Parameter(title: "Minutes", default: 15)
    var minutes: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = try await IntentServiceContainer.requireAuth()
        guard let nagId = UUID(uuidString: nag.id) else {
            throw NagzIntentError.notLoggedIn
        }

        let newDue = nag.dueAt.addingTimeInterval(TimeInterval(minutes * 60))
        let update = NagUpdate(dueAt: newDue)
        let _: NagResponse = try await api.request(.updateNag(nagId: nagId, update: update))

        return .result(dialog: "Snoozed for \(minutes) minutes.")
    }
}
