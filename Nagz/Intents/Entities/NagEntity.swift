import AppIntents
import Foundation

struct NagEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Nag" }
    static var defaultQuery: NagEntityQuery { NagEntityQuery() }

    var id: String
    var category: String
    var status: String
    var dueAt: Date
    var recipientName: String
    var nagDescription: String?

    var displayRepresentation: DisplayRepresentation {
        let subtitle = "Due \(dueAt.formatted(.relative(presentation: .named)))"
        return DisplayRepresentation(
            title: "\(category.capitalized) — \(recipientName)",
            subtitle: LocalizedStringResource(stringLiteral: subtitle)
        )
    }

    init(id: String, category: String, status: String, dueAt: Date, recipientName: String, nagDescription: String? = nil) {
        self.id = id
        self.category = category
        self.status = status
        self.dueAt = dueAt
        self.recipientName = recipientName
        self.nagDescription = nagDescription
    }

    init(from nag: NagResponse, recipientName: String) {
        self.init(
            id: nag.id.uuidString,
            category: nag.category.rawValue,
            status: nag.status.rawValue,
            dueAt: nag.dueAt,
            recipientName: recipientName,
            nagDescription: nag.description
        )
    }
}
