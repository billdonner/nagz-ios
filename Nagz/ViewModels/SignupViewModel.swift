import Foundation
import Observation

@Observable
@MainActor
final class SignupViewModel {
    var email = ""
    var password = ""
    var displayName = ""
    var dateOfBirth: Date?
    var errorMessage: String?
    var isLoading = false

    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    var isValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 8
            && dateOfBirth != nil
    }

    var isUnder13: Bool {
        guard let dob = dateOfBirth else { return false }
        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
        return age < 13
    }

    func signup() async {
        isLoading = true
        errorMessage = nil
        let name = displayName.trimmingCharacters(in: .whitespaces)
        do {
            try await authManager.signup(
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                password: password,
                displayName: name.isEmpty ? nil : name,
                dateOfBirth: dateOfBirth
            )
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
