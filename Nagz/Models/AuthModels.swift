import Foundation

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct SignupRequest: Encodable {
    let email: String
    let password: String
    let displayName: String?
    let dateOfBirth: Date?
}

struct RefreshRequest: Encodable {
    let refreshToken: String
}

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let user: AccountResponse
}

struct AccountResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let email: String?
    let displayName: String?
    let status: String
    let createdAt: Date
}
