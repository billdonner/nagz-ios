import Foundation
import Observation

@Observable
@MainActor
final class SafetyViewModel {
    var isSubmitting = false
    var reportCreated = false
    var blockCreated = false
    var errorMessage: String?

    // Report form
    var reportReason = ""

    // Block
    var blockTarget: UUID?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func submitAbuseReport(targetId: UUID) async {
        guard !reportReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let _: AbuseReportResponse = try await apiClient.request(
                .createAbuseReport(targetId: targetId, reason: reportReason)
            )
            reportCreated = true
            reportReason = ""
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    func blockUser(targetId: UUID) async {
        isSubmitting = true
        errorMessage = nil
        do {
            let _: BlockResponse = try await apiClient.request(.createBlock(targetId: targetId))
            blockCreated = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    func unblock(blockId: UUID) async {
        isSubmitting = true
        errorMessage = nil
        do {
            let _: BlockResponse = try await apiClient.request(
                .updateBlock(blockId: blockId, state: .lifted)
            )
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
