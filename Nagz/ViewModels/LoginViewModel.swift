import Foundation
import Observation

@Observable
@MainActor
final class LoginViewModel {
    var email = ""
    var password = ""
    var errorMessage: String?
    var isLoading = false

    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    var isValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 8
    }

    func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.login(email: email.trimmingCharacters(in: .whitespaces).lowercased(), password: password)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
