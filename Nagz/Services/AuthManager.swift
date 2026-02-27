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
            UserDefaults.standard.set(response.user.id.uuidString, forKey: "nagz_user_id")
            DebugLogger.shared.log("Session restored successfully")
        } catch {
            DebugLogger.shared.log("Session restore failed: \(error)", level: .error)
            try? await keychainService.clearTokens()
            state = .unauthenticated
        }
    }

    func login(email: String, password: String) async throws {
        DebugLogger.shared.log("Login attempt for \(email)")
        let response: AuthResponse = try await apiClient.request(.login(email: email, password: password))
        try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
        state = .authenticated(user: response.user)
        currentRole = nil // Regular login — role determined by family membership
        UserDefaults.standard.set(response.user.id.uuidString, forKey: "nagz_user_id")
        UserDefaults.standard.removeObject(forKey: "nagz_family_role")
        DebugLogger.shared.log("Login successful")
    }

    func childLogin(familyCode: String, username: String, pin: String) async throws {
        DebugLogger.shared.log("Child login attempt for \(username)")
        let response: AuthResponse = try await apiClient.request(
            .childLogin(familyCode: familyCode, username: username, pin: pin)
        )
        try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
        state = .authenticated(user: response.user)

        // Store family context from child login
        if let familyId = response.familyId {
            UserDefaults.standard.set(familyId.uuidString, forKey: "nagz_family_id")
        }
        if let role = response.familyRole, let familyRole = FamilyRole(rawValue: role) {
            currentRole = familyRole
            UserDefaults.standard.set(role, forKey: "nagz_family_role")
        }
        UserDefaults.standard.set(response.user.id.uuidString, forKey: "nagz_user_id")
        DebugLogger.shared.log("Child login successful")
    }

    func signup(email: String, password: String, displayName: String?, dateOfBirth: Date? = nil) async throws {
        DebugLogger.shared.log("Signup attempt for \(email)")
        let response: AuthResponse = try await apiClient.request(.signup(email: email, password: password, displayName: displayName, dateOfBirth: dateOfBirth))
        try await keychainService.saveTokens(access: response.accessToken, refresh: response.refreshToken)
        state = .authenticated(user: response.user)
        currentRole = nil
        UserDefaults.standard.set(response.user.id.uuidString, forKey: "nagz_user_id")
        UserDefaults.standard.removeObject(forKey: "nagz_family_role")
        DebugLogger.shared.log("Signup successful")
    }

    func logout() async {
        DebugLogger.shared.log("Logout initiated")
        try? await apiClient.requestVoid(.logout())
        try? await keychainService.clearTokens()
        await apiClient.clearCache()
        try? await syncService?.clearCache()
        currentRole = nil
        UserDefaults.standard.removeObject(forKey: "nagz_user_id")
        UserDefaults.standard.removeObject(forKey: "nagz_family_id")
        UserDefaults.standard.removeObject(forKey: "nagz_family_role")
        state = .unauthenticated
        DebugLogger.shared.log("Logout completed")
    }
}
