import Foundation
import Observation

@Observable
@MainActor
final class GamificationViewModel {
    var summary: GamificationSummary?
    var leaderboard: LeaderboardResponse?
    var events: [GamificationEventResponse] = []
    var isLoading = false
    var errorMessage: String?

    private let apiClient: APIClient
    private let familyId: UUID
    private let userId: UUID

    init(apiClient: APIClient, familyId: UUID, userId: UUID) {
        self.apiClient = apiClient
        self.familyId = familyId
        self.userId = userId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let loadedSummary: GamificationSummary = try await apiClient.request(
                .gamificationSummary(familyId: familyId)
            )
            summary = loadedSummary
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isLoading = false
            return
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        // Load leaderboard and events in sequence (both depend on gamification being enabled)
        do {
            let loadedLeaderboard: LeaderboardResponse = try await apiClient.request(
                .gamificationLeaderboard(familyId: familyId)
            )
            leaderboard = loadedLeaderboard
        } catch {
            // Leaderboard might not exist yet
        }

        do {
            let response: PaginatedResponse<GamificationEventResponse> = try await apiClient.request(
                .gamificationEvents(userId: userId, familyId: familyId, limit: 20)
            )
            events = response.items
        } catch {
            // Events might be empty
        }

        isLoading = false
    }
}
