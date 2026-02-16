import Foundation
import KeychainAccess

actor KeychainService {
    private let keychain: Keychain

    init() {
        self.keychain = Keychain(service: Constants.Keychain.serviceName)
            .accessibility(.afterFirstUnlock)
    }

    var accessToken: String? {
        try? keychain.get(Constants.Keychain.accessTokenKey)
    }

    var refreshToken: String? {
        try? keychain.get(Constants.Keychain.refreshTokenKey)
    }

    func saveTokens(access: String, refresh: String) throws {
        try keychain.set(access, key: Constants.Keychain.accessTokenKey)
        try keychain.set(refresh, key: Constants.Keychain.refreshTokenKey)
    }

    func clearTokens() throws {
        try keychain.remove(Constants.Keychain.accessTokenKey)
        try keychain.remove(Constants.Keychain.refreshTokenKey)
    }
}
