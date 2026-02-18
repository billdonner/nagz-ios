import Foundation

struct LegalDocument: Decodable, Sendable {
    let title: String
    let version: String
    let effectiveDate: String
    let content: String
}
