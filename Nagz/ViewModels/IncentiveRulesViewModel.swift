import Foundation
import Observation

@Observable
@MainActor
final class IncentiveRulesViewModel {
    var rules: [IncentiveRuleResponse] = []
    var isLoading = false
    var errorMessage: String?

    // Create rule
    var showCreateSheet = false
    var newConditionType = "nag_completed"
    var newConditionCount = 5
    var newActionType = "bonus_points"
    var newActionAmount = 50
    var newApprovalMode: IncentiveApprovalMode = .auto
    var isCreating = false

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
            let response: PaginatedResponse<IncentiveRuleResponse> = try await apiClient.request(
                .listIncentiveRules(familyId: familyId)
            )
            rules = response.items
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createRule() async {
        isCreating = true
        errorMessage = nil
        let condition: [String: AnyCodableValue] = [
            "type": .string(newConditionType),
            "count": .int(newConditionCount)
        ]
        let action: [String: AnyCodableValue] = [
            "type": .string(newActionType),
            "amount": .int(newActionAmount)
        ]
        do {
            let rule = IncentiveRuleCreate(
                familyId: familyId,
                condition: condition,
                action: action,
                approvalMode: newApprovalMode
            )
            let _: IncentiveRuleResponse = try await apiClient.request(.createIncentiveRule(rule))
            showCreateSheet = false
            resetForm()
            await load()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }

    private func resetForm() {
        newConditionType = "nag_completed"
        newConditionCount = 5
        newActionType = "bonus_points"
        newActionAmount = 50
        newApprovalMode = .auto
    }
}
