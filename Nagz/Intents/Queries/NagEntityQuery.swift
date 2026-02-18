import AppIntents
import Foundation

struct NagEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [NagEntity] {
        let api = try await IntentServiceContainer.requireAuth()
        var results: [NagEntity] = []
        for id in identifiers {
            guard let uuid = UUID(uuidString: id) else { continue }
            let nag: NagResponse = try await api.request(.getNag(id: uuid))
            let memberName = await Self.resolveMemberName(nag.recipientId, api: api)
            results.append(NagEntity(from: nag, recipientName: memberName))
        }
        return results
    }

    func entities(matching string: String) async throws -> [NagEntity] {
        let api = try await IntentServiceContainer.requireAuth()
        let familyId = try IntentServiceContainer.currentFamilyId()
        let response: PaginatedResponse<NagResponse> = try await api.request(
            .listNags(familyId: familyId, status: .open)
        )
        let members = try await Self.fetchMembers(familyId: familyId, api: api)
        let query = string.lowercased()
        return response.items
            .filter { nag in
                nag.category.rawValue.contains(query) ||
                (nag.description?.lowercased().contains(query) ?? false)
            }
            .map { nag in
                let name = members[nag.recipientId] ?? String(nag.recipientId.uuidString.prefix(8))
                return NagEntity(from: nag, recipientName: name)
            }
    }

    func suggestedEntities() async throws -> [NagEntity] {
        let api = try await IntentServiceContainer.requireAuth()
        let familyId = try IntentServiceContainer.currentFamilyId()
        let response: PaginatedResponse<NagResponse> = try await api.request(
            .listNags(familyId: familyId, status: .open, limit: 10)
        )
        let members = try await Self.fetchMembers(familyId: familyId, api: api)
        return response.items.map { nag in
            let name = members[nag.recipientId] ?? String(nag.recipientId.uuidString.prefix(8))
            return NagEntity(from: nag, recipientName: name)
        }
    }

    private static func fetchMembers(familyId: UUID, api: APIClient) async throws -> [UUID: String] {
        let response: PaginatedResponse<MemberDetail> = try await api.request(
            .listMembers(familyId: familyId)
        )
        var map: [UUID: String] = [:]
        for member in response.items {
            map[member.userId] = member.displayName ?? String(member.userId.uuidString.prefix(8))
        }
        return map
    }

    private static func resolveMemberName(_ userId: UUID, api: APIClient) async -> String {
        do {
            let familyId = try IntentServiceContainer.currentFamilyId()
            let members = try await fetchMembers(familyId: familyId, api: api)
            return members[userId] ?? String(userId.uuidString.prefix(8))
        } catch {
            return String(userId.uuidString.prefix(8))
        }
    }
}
