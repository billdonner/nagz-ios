import AppIntents
import Foundation

struct FamilyStatusIntent: AppIntent {
    static var title: LocalizedStringResource { "Family Status" }
    static var description: IntentDescription { "Get this week's family completion rate." }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let api = try await IntentServiceContainer.requireAuth()
        let familyId = try IntentServiceContainer.currentFamilyId()

        let report: WeeklyReportResponse = try await api.request(.weeklyReport(familyId: familyId))

        let total = report.metrics.totalNags
        guard total > 0 else {
            return .result(dialog: "No nags this week yet.")
        }

        let rate = Int(Double(report.metrics.completed) / Double(total) * 100)
        return .result(dialog: "This week: \(rate)% completion rate across \(total) nags.")
    }
}
