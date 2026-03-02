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
    private(set) var currentRole: FamilyRole?

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

    var isChildUser: Bool {
        currentRole == .child
    }

    init(apiClient: APIClient, keychainService: KeychainService, syncService: SyncService? = nil) {
        self.apiClient = apiClient
        self.keychainService = keychainService
        self.syncService = syncService

        // Restore role from UserDefaults
        if let savedRole = UserDefaults.standard.string(forKey: "nagz_family_role") {
            self.currentRole = FamilyRole(rawValue: savedRole)
        }

        // Instant restore from cached user — skip the loading spinner entirely
        if let cachedUser = Self.loadCachedUser() {
            state = .authenticated(user: cachedUser)
            DebugLogger.shared.log("Session restored from cache (instant)")
        }

        Task {
            await apiClient.setOnUnauthorized { [weak self] in
                Task { @MainActor in
                    self?.state = .unauthenticated
                    self?.currentRole = nil
                }
            }
        }
    }

    func restoreSession() async {
        // If already authenticated from cache, just refresh tokens in background
        if case .authenticated = state {
            await refreshTokensInBackground()
            return
        }

        DebugLogger.shared.log("Restoring session...")
        let hasToken = await keychainService.accessToken != nil
        guard hasToken else {
            DebugLogger.shared.log("Session restore: no access token", level: .warning)
            state = .unauthenticated
            return
        }

        // Try to refresh to validate the session
        guard let refreshToken = await keychainService.refreshToken else {
            DebugLogger.shared.log("Session restore: no refresh token", level: .warning)
            state = .unauthenticated
            return
        }

        do {
            let response: AuthResponse = try await apiClient.request(.refresh(refreshToken: refreshToken))
            try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
            state = .authenticated(user: response.user)
            Self.cacheUser(response.user)
            DebugLogger.shared.log("Session restored successfully")
        } catch {
            DebugLogger.shared.log("Session restore failed: \(error)", level: .error)
            try? await keychainService.clearTokens()
            Self.clearCachedUser()
            state = .unauthenticated
        }
    }

    private func refreshTokensInBackground() async {
        guard let refreshToken = await keychainService.refreshToken else {
            DebugLogger.shared.log("Background refresh: no refresh token", level: .warning)
            Self.clearCachedUser()
            state = .unauthenticated
            return
        }

        do {
            let response: AuthResponse = try await apiClient.request(.refresh(refreshToken: refreshToken))
            try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
            state = .authenticated(user: response.user)
            Self.cacheUser(response.user)
            DebugLogger.shared.log("Background token refresh succeeded")
        } catch {
            DebugLogger.shared.log("Background token refresh failed: \(error)", level: .warning)
            try? await keychainService.clearTokens()
            Self.clearCachedUser()
            state = .unauthenticated
        }
    }

    // MARK: - User Cache

    private static let cachedUserKey = "nagz_cached_user"

    private static func cacheUser(_ user: AccountResponse) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: cachedUserKey)
        }
        UserDefaults.standard.set(user.id.uuidString, forKey: "nagz_user_id")
    }

    private static func loadCachedUser() -> AccountResponse? {
        guard let data = UserDefaults.standard.data(forKey: cachedUserKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AccountResponse.self, from: data)
    }

    private static func clearCachedUser() {
        UserDefaults.standard.removeObject(forKey: cachedUserKey)
    }

    func login(email: String, password: String) async throws {
        DebugLogger.shared.log("Login attempt for \(email)")
        let response: AuthResponse = try await apiClient.request(.login(email: email, password: password))
        try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
        state = .authenticated(user: response.user)
        Self.cacheUser(response.user)
        // Restore family context from login response
        if let familyId = response.familyId {
            UserDefaults.standard.set(familyId.uuidString, forKey: "nagz_family_id")
        }
        if let role = response.familyRole, let familyRole = FamilyRole(rawValue: role) {
            currentRole = familyRole
            UserDefaults.standard.set(role, forKey: "nagz_family_role")
        } else {
            currentRole = nil
            UserDefaults.standard.removeObject(forKey: "nagz_family_role")
        }
        DebugLogger.shared.log("Login successful")
    }

    func childLogin(familyCode: String, username: String, pin: String) async throws {
        DebugLogger.shared.log("Child login attempt for \(username)")
        let response: AuthResponse = try await apiClient.request(
            .childLogin(familyCode: familyCode, username: username, pin: pin)
        )
        try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
        state = .authenticated(user: response.user)
        Self.cacheUser(response.user)

        // Store family context from child login
        if let familyId = response.familyId {
            UserDefaults.standard.set(familyId.uuidString, forKey: "nagz_family_id")
        }
        if let role = response.familyRole, let familyRole = FamilyRole(rawValue: role) {
            currentRole = familyRole
            UserDefaults.standard.set(role, forKey: "nagz_family_role")
        }
        DebugLogger.shared.log("Child login successful")
    }

    func signup(email: String, password: String, displayName: String?, dateOfBirth: Date? = nil) async throws {
        DebugLogger.shared.log("Signup attempt for \(email)")
        let response: AuthResponse = try await apiClient.request(.signup(email: email, password: password, displayName: displayName, dateOfBirth: dateOfBirth))
        try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
        state = .authenticated(user: response.user)
        Self.cacheUser(response.user)
        currentRole = nil
        UserDefaults.standard.removeObject(forKey: "nagz_family_role")
        DebugLogger.shared.log("Signup successful")
    }

    func logout() async {
        DebugLogger.shared.log("Logout initiated")
        try? await apiClient.requestVoid(.logout())
        try? await keychainService.clearTokens()
        await apiClient.clearCache()
        try? await syncService?.clearCache()
        Self.clearCachedUser()
        currentRole = nil
        UserDefaults.standard.removeObject(forKey: "nagz_user_id")
        UserDefaults.standard.removeObject(forKey: "nagz_family_id")
        UserDefaults.standard.removeObject(forKey: "nagz_family_role")
        state = .unauthenticated
        DebugLogger.shared.log("Logout completed")
    }
}
