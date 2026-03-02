import Foundation
import Observation

@Observable
@MainActor
final class ManageMembersViewModel {
    var members: [MemberDetail] = []
    var isLoading = false
    var errorMessage: String?

    // Create member sheet
    var showCreateSheet = false
    var newMemberName = ""
    var newMemberRole: FamilyRole = .child
    var isCreating = false

    // Remove member
    var isRemoving = false
    var memberToRemove: MemberDetail?
    var showRemoveConfirmation = false

    let apiClient: APIClient
    let familyId: UUID

    init(apiClient: APIClient, familyId: UUID) {
        self.apiClient = apiClient
        self.familyId = familyId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: PaginatedResponse<MemberDetail> = try await apiClient.request(
                .listMembers(familyId: familyId, limit: 200)
            )
            members = response.items
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createMember() async {
        guard !newMemberName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isCreating = true
        errorMessage = nil
        do {
            let _: MemberDetail = try await apiClient.request(
                .createMember(familyId: familyId, displayName: newMemberName.trimmingCharacters(in: .whitespaces), role: newMemberRole)
            )
            await apiClient.invalidateCache(prefix: "/families")
            showCreateSheet = false
            newMemberName = ""
            newMemberRole = .child
            await load()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }

    func removeMember(_ member: MemberDetail) async {
        isRemoving = true
        errorMessage = nil
        do {
            let _: MemberResponse = try await apiClient.request(
                .removeMember(familyId: familyId, userId: member.userId)
            )
            await apiClient.invalidateCache(prefix: "/families")
            await load()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isRemoving = false
    }
}
