import Foundation
import Observation

@Observable
@MainActor
final class MemberListViewModel {
    var members: [MemberDetail] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    private let apiClient: APIClient
    private let familyId: UUID
    private var total = 0
    private var offset = 0

    init(apiClient: APIClient, familyId: UUID) {
        self.apiClient = apiClient
        self.familyId = familyId
    }

    var hasMore: Bool {
        offset < total
    }

    func loadMembers() async {
        isLoading = true
        errorMessage = nil
        offset = 0
        do {
            let response: PaginatedResponse<MemberDetail> = try await apiClient.request(
                .listMembers(familyId: familyId, offset: 0)
            )
            members = response.items
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
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let response: PaginatedResponse<MemberDetail> = try await apiClient.request(
                .listMembers(familyId: familyId, offset: offset)
            )
            let existingIds = Set(members.map(\.userId))
            let newItems = response.items.filter { !existingIds.contains($0.userId) }
            members.append(contentsOf: newItems)
            total = response.total
            offset += response.items.count
        } catch {
            // Silently fail for pagination
        }
        isLoadingMore = false
    }
}
