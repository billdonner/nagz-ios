import Foundation

struct VersionResponse: Codable, Sendable {
    let serverVersion: String
    let apiVersion: String
    let minClientVersion: String
}
