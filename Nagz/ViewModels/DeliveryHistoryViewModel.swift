import Foundation
import Observation

@Observable
@MainActor
final class DeliveryHistoryViewModel {
    var deliveries: [DeliveryResponse] = []
    var isLoading = false
    var errorMessage: String?

    private let apiClient: APIClient
    private let nagId: UUID

    init(apiClient: APIClient, nagId: UUID) {
        self.apiClient = apiClient
        self.nagId = nagId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: PaginatedResponse<DeliveryResponse> = try await apiClient.request(
                .listDeliveries(nagId: nagId)
            )
            deliveries = response.items
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}
