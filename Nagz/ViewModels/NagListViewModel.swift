import Foundation
import Observation

enum NagFilter: String, CaseIterable {
    case open = "Open"
    case completed = "Done"
    case all = "All"

    var nagStatus: NagStatus? {
        switch self {
        case .open: .open
        case .completed: .completed
        case .all: nil   // All includes missed nags
        }
    }
}

@Observable
@MainActor
final class NagListViewModel {
    var loadState: LoadState<[NagResponse]> = .idle
    var filter: NagFilter = .open
    var isLoadingMore = false

    let apiClient: APIClient
    private var familyId: UUID?
    private var total = 0
    private var offset = 0

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Current nags — empty during loading/error, populated on success.
    var nags: [NagResponse] { loadState.value ?? [] }

    var hasMore: Bool { offset < total }

    func setFamily(_ familyId: UUID?) {
        self.familyId = familyId
    }

    func loadNags() async {
        guard !loadState.isLoading else { return }
        // Keep showing existing data during refresh; only go to .loading on first load.
        if loadState.value == nil { loadState = .loading }
        offset = 0
        do {
            let shouldExcludeDismissed = filter == .open
            let familyResponse: PaginatedResponse<NagResponse> = try await apiClient.request(
                .listNags(familyId: familyId, status: filter.nagStatus, excludeDismissed: shouldExcludeDismissed, offset: 0)
            )
            var allNags = familyResponse.items
            total = familyResponse.total

            if familyId != nil {
                let connectionResponse: PaginatedResponse<NagResponse> = try await apiClient.request(
                    .listNags(status: filter.nagStatus, excludeDismissed: shouldExcludeDismissed, offset: 0)
                )
                let familyIds = Set(allNags.map(\.id))
                let connectionOnly = connectionResponse.items.filter { !familyIds.contains($0.id) }
                allNags.append(contentsOf: connectionOnly)
                total += connectionOnly.count
            }

            allNags.sort { $0.dueAt > $1.dueAt }
            loadState = .success(allNags)
            offset = allNags.count
        } catch {
            // On refresh failure, keep existing data rather than blanking the screen.
            if loadState.value == nil {
                loadState = .failure(error)
            }
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, case .success(var existing) = loadState else { return }
        isLoadingMore = true
        do {
            let response: PaginatedResponse<NagResponse> = try await apiClient.request(
                .listNags(familyId: familyId, status: filter.nagStatus, offset: offset)
            )
            existing.append(contentsOf: response.items)
            total = response.total
            offset += response.items.count
            loadState = .success(existing)
        } catch {
            DebugLogger.shared.log("Pagination load failed: \(error.localizedDescription)", level: .warning)
        }
        isLoadingMore = false
    }

    func refresh() async {
        await loadNags()
    }
}
