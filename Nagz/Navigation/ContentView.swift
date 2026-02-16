import SwiftUI

struct ContentView: View {
    let authManager: AuthManager
    let apiClient: APIClient
    let pushService: PushNotificationService

    var body: some View {
        switch authManager.state {
        case .unknown:
            ProgressView("Loading...")
                .task { await authManager.restoreSession() }

        case .unauthenticated:
            AuthFlowView(authManager: authManager)

        case .authenticated:
            AuthenticatedTabView(
                authManager: authManager,
                apiClient: apiClient,
                pushService: pushService
            )
        }
    }
}

private struct AuthFlowView: View {
    let authManager: AuthManager
    @State private var showSignup = false

    var body: some View {
        NavigationStack {
            LoginView(authManager: authManager, showSignup: $showSignup)
        }
        .sheet(isPresented: $showSignup) {
            SignupView(authManager: authManager)
        }
    }
}
