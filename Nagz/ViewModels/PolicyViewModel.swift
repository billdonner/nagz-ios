import Foundation
import Observation

@Observable
@MainActor
final class PolicyViewModel {
    private let apiClient: APIClient
    private let familyId: UUID

    private(set) var policies: [PolicyResponse] = []
    private(set) var approvals: [ApprovalResponse] = []
    private(set) var isLoading = false
    private(set) var error: String?

    var isSubmitting = false

    init(apiClient: APIClient, familyId: UUID) {
        self.apiClient = apiClient
        self.familyId = familyId
    }

    func loadPolicies() async {
        isLoading = true
        error = nil
        do {
            let response: PaginatedResponse<PolicyResponse> = try await apiClient.request(
                .listPolicies(familyId: familyId)
            )
            policies = response.items
        } catch let err as APIError {
            error = err.errorDescription
        } catch let err {
            error = err.localizedDescription
        }
        isLoading = false
    }

    func loadApprovals(policyId: UUID) async {
        do {
            let response: PaginatedResponse<ApprovalResponse> = try await apiClient.request(
                .listApprovals(policyId: policyId)
            )
            approvals = response.items
        } catch let err as APIError {
            error = err.errorDescription
        } catch let err {
            error = err.localizedDescription
        }
    }

    func updatePolicy(policyId: UUID, update: PolicyUpdate) async {
        isSubmitting = true
        error = nil
        do {
            let _: PolicyResponse = try await apiClient.request(
                .updatePolicy(policyId: policyId, update: update)
            )
            await loadPolicies()
        } catch let err as APIError {
            error = err.errorDescription
        } catch let err {
            error = err.localizedDescription
        }
        isSubmitting = false
    }

    func createApproval(policyId: UUID, comment: String?) async {
        isSubmitting = true
        error = nil
        do {
            let _: ApprovalResponse = try await apiClient.request(
                .createApproval(policyId: policyId, comment: comment)
            )
            await loadApprovals(policyId: policyId)
        } catch let err as APIError {
            error = err.errorDescription
        } catch let err {
            error = err.localizedDescription
        }
        isSubmitting = false
    }
}
