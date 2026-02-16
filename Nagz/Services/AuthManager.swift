import Foundation
import Observation

enum AuthState: Sendable {
    case unknown
    case unauthenticated
    case authenticated(user: AccountResponse)
}

@Observable
@MainActor
final class AuthManager {
    private(set) var state: AuthState = .unknown

    private let apiClient: APIClient
    private let keychainService: KeychainService

    var currentUser: AccountResponse? {
        if case .authenticated(let user) = state { return user }
        return nil
    }

    var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }

    init(apiClient: APIClient, keychainService: KeychainService) {
        self.apiClient = apiClient
        self.keychainService = keychainService

        Task {
            await apiClient.setOnUnauthorized { [weak self] in
                Task { @MainActor in
                    self?.state = .unauthenticated
                }
            }
        }
    }

    func restoreSession() async {
        let hasToken = await keychainService.accessToken != nil
        guard hasToken else {
            state = .unauthenticated
            return
        }

        // Try to refresh to validate the session
        let hasRefresh = await keychainService.refreshToken != nil
        guard hasRefresh else {
            state = .unauthenticated
            return
        }

        do {
            let refreshToken = await keychainService.refreshToken!
            let response: AuthResponse = try await apiClient.request(.refresh(refreshToken: refreshToken))
            try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
            state = .authenticated(user: response.user)
        } catch {
            try? await keychainService.clearTokens()
            state = .unauthenticated
        }
    }

    func login(email: String, password: String) async throws {
        let response: AuthResponse = try await apiClient.request(.login(email: email, password: password))
        try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
        state = .authenticated(user: response.user)
    }

    func signup(email: String, password: String, displayName: String?) async throws {
        let response: AuthResponse = try await apiClient.request(.signup(email: email, password: password, displayName: displayName))
        try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
        state = .authenticated(user: response.user)
    }

    func logout() async {
        try? await apiClient.requestVoid(.logout())
        try? await keychainService.clearTokens()
        state = .unauthenticated
    }
}
