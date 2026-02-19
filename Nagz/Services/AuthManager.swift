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
    private let syncService: SyncService?

    var currentUser: AccountResponse? {
        if case .authenticated(let user) = state { return user }
        return nil
    }

    var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }

    init(apiClient: APIClient, keychainService: KeychainService, syncService: SyncService? = nil) {
        self.apiClient = apiClient
        self.keychainService = keychainService
        self.syncService = syncService

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
        guard let refreshToken = await keychainService.refreshToken else {
            state = .unauthenticated
            return
        }

        do {
            let response: AuthResponse = try await apiClient.request(.refresh(refreshToken: refreshToken))
            try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
            state = .authenticated(user: response.user)
            UserDefaults.standard.set(response.user.id.uuidString, forKey: "nagz_user_id")
        } catch {
            try? await keychainService.clearTokens()
            state = .unauthenticated
        }
    }

    func login(email: String, password: String) async throws {
        let response: AuthResponse = try await apiClient.request(.login(email: email, password: password))
        try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
        state = .authenticated(user: response.user)
        UserDefaults.standard.set(response.user.id.uuidString, forKey: "nagz_user_id")
    }

    func signup(email: String, password: String, displayName: String?, dateOfBirth: Date? = nil) async throws {
        let response: AuthResponse = try await apiClient.request(.signup(email: email, password: password, displayName: displayName, dateOfBirth: dateOfBirth))
        try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
        state = .authenticated(user: response.user)
        UserDefaults.standard.set(response.user.id.uuidString, forKey: "nagz_user_id")
    }

    func logout() async {
        try? await apiClient.requestVoid(.logout())
        try? await keychainService.clearTokens()
        await apiClient.clearCache()
        try? await syncService?.clearCache()
        UserDefaults.standard.removeObject(forKey: "nagz_user_id")
        UserDefaults.standard.removeObject(forKey: "nagz_family_id")
        state = .unauthenticated
    }
}
