import Foundation

struct ErrorEnvelope: Decodable {
    let error: ErrorResponse
}

struct ErrorResponse: Decodable {
    let code: String
    let message: String
    let requestId: String?
    let details: ErrorDetails?
}

struct ErrorDetails: Decodable {
    let field: String?
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case validationError(String)
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)
    case unknown(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .unauthorized:
            return "Session expired. Please log in again."
        case .forbidden:
            return "You don't have permission for this action."
        case .notFound:
            return "The requested resource was not found."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .validationError(let message):
            return message
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            let nsError = error as NSError
            if nsError.code == NSURLErrorNotConnectedToInternet {
                return "No internet connection. Please check your network."
            }
            if nsError.code == NSURLErrorTimedOut {
                return "Request timed out. Please try again."
            }
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data error: \(error.localizedDescription)"
        case .unknown(let code, let message):
            return "Error \(code): \(message)"
        }
    }

    /// Whether this error is likely transient and retrying may succeed.
    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .rateLimited:
            true
        default:
            false
        }
    }
}
