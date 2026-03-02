import Foundation
import NagzAI
import Observation

@Observable
@MainActor
final class GamificationViewModel {
    var summary: GamificationSummary?
    var leaderboard: LeaderboardResponse?
    var events: [GamificationEventResponse] = []
    var badges: [BadgeResponse] = []
    var nudges: [GamificationNudgeItem] = []
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

        do {
            let loadedBadges: [BadgeResponse] = try await apiClient.request(
                .gamificationBadges(userId: userId, familyId: familyId)
            )
            badges = loadedBadges
        } catch {
            // Badges might not be available
        }

        // Generate AI nudges from loaded gamification data
        if let summary {
            let context = GamificationContext(
                currentStreak: summary.currentStreak,
                totalCompletions: summary.eventCount,
                earnedBadgeTypes: badges.map(\.badgeType)
            )
            do {
                let result = try await Router(preferHeuristic: false).gamificationNudges(context: context)
                nudges = result.nudges
            } catch {
                // Nudges are optional — fail silently
            }
        }

        isLoading = false
    }
}
