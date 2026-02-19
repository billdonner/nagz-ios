import Foundation
import AppIntents

enum NagzIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notLoggedIn
    case noFamily
    case notPermitted
    case invalidNagId

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
        }
    }
}
