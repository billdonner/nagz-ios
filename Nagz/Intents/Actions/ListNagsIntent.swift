import AppIntents
import Foundation

struct ListNagsIntent: AppIntent {
    static var title: LocalizedStringResource { "List Active Nags" }
    static var description: IntentDescription { "Show your active nags, optionally filtered by category." }

    @Parameter(title: "Category")
    var category: NagCategoryAppEnum?

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<[NagEntity]> {
        let api = try await IntentServiceContainer.requireAuth()
        let familyId = try IntentServiceContainer.currentFamilyId()

        let response: PaginatedResponse<NagResponse> = try await api.request(
            .listNags(familyId: familyId, status: .open)
        )

        var nags = response.items
        if let category {
            nags = nags.filter { $0.category == category.nagCategory }
        }

        let membersResponse: PaginatedResponse<MemberDetail> = try await api.request(
            .listMembers(familyId: familyId)
        )
        var memberNames: [UUID: String] = [:]
        for member in membersResponse.items {
            memberNames[member.userId] = member.displayName ?? String(member.userId.uuidString.prefix(8))
        }

        let entities = nags.map { nag in
            let name = memberNames[nag.recipientId] ?? String(nag.recipientId.uuidString.prefix(8))
            return NagEntity(from: nag, recipientName: name)
        }

        let count = entities.count
        let noun = count == 1 ? "nag" : "nags"
        return .result(value: entities, dialog: "You have \(count) active \(noun).")
    }
}
