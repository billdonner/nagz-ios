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
    case validationError(String)
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)
    case unknown(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .unauthorized:
            "Session expired. Please log in again."
        case .forbidden:
            "You don't have permission for this action."
        case .notFound:
            "The requested resource was not found."
        case .validationError(let message):
            message
        case .serverError(let message):
            "Server error: \(message)"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            "Data error: \(error.localizedDescription)"
        case .unknown(let code, let message):
            "Error \(code): \(message)"
        }
    }
}
