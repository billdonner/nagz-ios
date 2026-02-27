import Foundation
import Observation

@Observable
@MainActor
final class ChildLoginViewModel {
    var familyCode = ""
    var username = ""
    var pin = ""
    var errorMessage: String?
    var isLoading = false

    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    var isValid: Bool {
        familyCode.count >= 6 &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }

    func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.childLogin(
                familyCode: familyCode.trimmingCharacters(in: .whitespaces),
                username: username.trimmingCharacters(in: .whitespaces),
                pin: pin
            )
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
