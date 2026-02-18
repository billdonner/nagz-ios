import AppIntents
import Foundation

struct FamilyMemberEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Family Member" }
    static var defaultQuery: FamilyMemberQuery { FamilyMemberQuery() }

    var id: String
    var displayName: String
    var role: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayName)",
            subtitle: LocalizedStringResource(stringLiteral: role.capitalized)
        )
    }

    init(id: String, displayName: String, role: String) {
        self.id = id
        self.displayName = displayName
        self.role = role
    }

    init(from member: MemberDetail) {
        self.init(
            id: member.userId.uuidString,
            displayName: member.displayName ?? String(member.userId.uuidString.prefix(8)),
            role: member.role.rawValue
        )
    }
}
