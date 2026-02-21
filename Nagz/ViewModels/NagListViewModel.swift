import Foundation
import Observation

enum NagFilter: String, CaseIterable {
    case open = "Open"
    case completed = "Completed"
    case missed = "Missed"
    case all = "All"

    var nagStatus: NagStatus? {
        switch self {
        case .open: .open
        case .completed: .completed
        case .missed: .missed
        case .all: nil
        }
    }
}

@Observable
@MainActor
final class NagListViewModel {
    var nags: [NagResponse] = []
    var filter: NagFilter = .open
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    let apiClient: APIClient
    private var familyId: UUID?
    private var total = 0
    private var offset = 0

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var hasMore: Bool {
        offset < total
    }

    func setFamily(_ familyId: UUID) {
        self.familyId = familyId
    }

    func loadNags() async {
        guard let familyId else { return }
        isLoading = true
        errorMessage = nil
        offset = 0
        do {
            let response: PaginatedResponse<NagResponse> = try await apiClient.request(
                .listNags(familyId: familyId, status: filter.nagStatus, offset: 0)
            )
            nags = response.items
            total = response.total
            offset = response.items.count
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard let familyId, hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let response: PaginatedResponse<NagResponse> = try await apiClient.request(
                .listNags(familyId: familyId, status: filter.nagStatus, offset: offset)
            )
            nags.append(contentsOf: response.items)
            total = response.total
            offset += response.items.count
        } catch {
            print("Pagination load failed: \(error.localizedDescription)")
        }
        isLoadingMore = false
    }

    func refresh() async {
        await loadNags()
    }
}
