import Foundation
import Observation

@Observable
@MainActor
final class ReportsViewModel {
    var weeklyReport: WeeklyReportResponse?
    var metrics: FamilyMetricsResponse?
    var isLoading = false
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
            weeklyReport = try await apiClient.request(.weeklyReport(familyId: familyId))
        } catch {
            // Weekly report may not be available
        }

        do {
            metrics = try await apiClient.request(.familyMetrics(familyId: familyId))
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }
}
