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

    func setFamily(_ familyId: UUID?) {
        self.familyId = familyId
    }

    func loadNags() async {
        isLoading = true
        errorMessage = nil
        offset = 0
        do {
            // Fetch family-scoped nags
            let familyResponse: PaginatedResponse<NagResponse> = try await apiClient.request(
                .listNags(familyId: familyId, status: filter.nagStatus, offset: 0)
            )
            var allNags = familyResponse.items
            total = familyResponse.total

            // Also fetch connection nags (where user is creator/recipient via connections)
            if familyId != nil {
                let connectionResponse: PaginatedResponse<NagResponse> = try await apiClient.request(
                    .listNags(status: filter.nagStatus, offset: 0)
                )
                // Merge: add connection nags not already in the family list
                let familyIds = Set(allNags.map(\.id))
                let connectionOnly = connectionResponse.items.filter { !familyIds.contains($0.id) }
                allNags.append(contentsOf: connectionOnly)
                total += connectionOnly.count
            }

            // Sort by due date (newest first)
            allNags.sort { $0.dueAt > $1.dueAt }
            nags = allNags
            offset = nags.count
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let response: PaginatedResponse<NagResponse> = try await apiClient.request(
                .listNags(familyId: familyId, status: filter.nagStatus, offset: offset)
            )
            nags.append(contentsOf: response.items)
            total = response.total
            offset += response.items.count
        } catch {
            DebugLogger.shared.log("Pagination load failed: \(error.localizedDescription)", level: .warning)
        }
        isLoadingMore = false
    }

    func refresh() async {
        await loadNags()
    }
}
