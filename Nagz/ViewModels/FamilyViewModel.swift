import Foundation
import Observation

@Observable
@MainActor
final class FamilyViewModel {
    var family: FamilyResponse?
    var members: [MemberDetail] = []
    var isLoading = false
    var errorMessage: String?
    var showCreateSheet = false
    var showJoinSheet = false

    // Create family fields
    var newFamilyName = ""
    var isCreating = false

    // Join family fields
    var joinInviteCode = ""
    var isJoining = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadFamily(id: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let loadedFamily: FamilyResponse = try await apiClient.request(.getFamily(id: id))
            family = loadedFamily

            let membersResponse: PaginatedResponse<MemberDetail> = try await apiClient.request(
                .listMembers(familyId: id)
            )
            members = membersResponse.items
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createFamily() async {
        let name = newFamilyName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isCreating = true
        errorMessage = nil
        do {
            let created: FamilyResponse = try await apiClient.request(.createFamily(name: name))
            family = created
            showCreateSheet = false
            let membersResponse: PaginatedResponse<MemberDetail> = try await apiClient.request(
                .listMembers(familyId: created.familyId)
            )
            members = membersResponse.items
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }

    func joinFamily() async {
        let code = joinInviteCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else {
            errorMessage = "Invite code is required"
            return
        }
        isJoining = true
        errorMessage = nil
        do {
            let member: MemberResponse = try await apiClient.request(.joinFamily(inviteCode: code))
            showJoinSheet = false
            await loadFamily(id: member.familyId)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isJoining = false
    }
}
