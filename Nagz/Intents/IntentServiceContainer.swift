import Foundation

enum IntentServiceContainer {
    private static let keychain = KeychainService()
    private static let apiClient = APIClient(keychainService: keychain)

    static func requireAuth() async throws -> APIClient {
        guard await keychain.accessToken != nil else {
            throw NagzIntentError.notLoggedIn
        }
        return apiClient
    }

    static func currentFamilyId() throws -> UUID {
        guard let str = UserDefaults.standard.string(forKey: "nagz_family_id"),
              let id = UUID(uuidString: str) else {
            throw NagzIntentError.noFamily
        }
        return id
    }

    static func currentUserId() throws -> UUID {
        guard let str = UserDefaults.standard.string(forKey: "nagz_user_id"),
              let id = UUID(uuidString: str) else {
            throw NagzIntentError.notLoggedIn
        }
        return id
    }
}
