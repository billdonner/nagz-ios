import Foundation
import AppIntents

enum NagzIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notLoggedIn
    case noFamily
    case notPermitted
    case invalidNagId
    case apiFailure(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notLoggedIn:
            return "Please open Nagz and log in first."
        case .noFamily:
            return "No family selected. Open Nagz and join a family first."
        case .notPermitted:
            return "Your role doesn't have permission for this action."
        case .invalidNagId:
            return "Invalid nag ID. The nag may have been deleted."
        case .apiFailure(let message):
            return "\(message)"
        }
    }

    /// Wrap an API call so that APIError is converted to a user-friendly intent error.
    static func wrapAPI<T>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch let error as APIError {
            throw NagzIntentError.apiFailure(error.errorDescription ?? "Something went wrong. Please try again.")
        }
    }
}
