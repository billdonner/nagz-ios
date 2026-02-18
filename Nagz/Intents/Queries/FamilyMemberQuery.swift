import AppIntents
import Foundation

struct FamilyMemberQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [FamilyMemberEntity] {
        let api = try await IntentServiceContainer.requireAuth()
        let familyId = try IntentServiceContainer.currentFamilyId()
        let response: PaginatedResponse<MemberDetail> = try await api.request(
            .listMembers(familyId: familyId)
        )
        let idSet = Set(identifiers)
        return response.items
            .filter { idSet.contains($0.userId.uuidString) }
            .map { FamilyMemberEntity(from: $0) }
    }

    func entities(matching string: String) async throws -> [FamilyMemberEntity] {
        let api = try await IntentServiceContainer.requireAuth()
        let familyId = try IntentServiceContainer.currentFamilyId()
        let response: PaginatedResponse<MemberDetail> = try await api.request(
            .listMembers(familyId: familyId)
        )
        let query = string.lowercased()
        return response.items
            .filter { $0.status == .active }
            .filter { ($0.displayName?.lowercased().contains(query) ?? false) }
            .map { FamilyMemberEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [FamilyMemberEntity] {
        let api = try await IntentServiceContainer.requireAuth()
        let familyId = try IntentServiceContainer.currentFamilyId()
        let response: PaginatedResponse<MemberDetail> = try await api.request(
            .listMembers(familyId: familyId)
        )
        return response.items
            .filter { $0.status == .active }
            .map { FamilyMemberEntity(from: $0) }
    }
}
