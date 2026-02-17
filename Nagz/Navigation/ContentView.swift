import SwiftUI

struct ContentView: View {
    let authManager: AuthManager
    let apiClient: APIClient
    let pushService: PushNotificationService
    let versionChecker: VersionChecker

    @State private var showUpdateAlert = false
    @State private var updateAlertTitle = ""
    @State private var updateAlertMessage = ""
    @State private var isBlocked = false

    var body: some View {
        Group {
            switch authManager.state {
            case .unknown:
                ProgressView("Loading...")
                    .task { await authManager.restoreSession() }

            case .unauthenticated:
                AuthFlowView(authManager: authManager)

            case .authenticated:
                if isBlocked {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.red)
                        Text("Update Required")
                            .font(.title2.bold())
                        Text(updateAlertMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    AuthenticatedTabView(
                        authManager: authManager,
                        apiClient: apiClient,
                        pushService: pushService
                    )
                }
            }
        }
        .task {
            await versionChecker.check()
            handleVersionStatus()
        }
        .alert(updateAlertTitle, isPresented: $showUpdateAlert) {
            Button("OK") {}
        } message: {
            Text(updateAlertMessage)
        }
    }

    private func handleVersionStatus() {
        switch versionChecker.status {
        case .updateRequired(let minRequired, let clientAPI):
            updateAlertTitle = "Update Required"
            updateAlertMessage = "This app (v\(clientAPI)) is too old. The server requires at least v\(minRequired). Please update to continue."
            isBlocked = true
        case .updateRecommended(let serverAPI, let clientAPI):
            updateAlertTitle = "Update Available"
            updateAlertMessage = "A newer API version (\(serverAPI)) is available. You are on v\(clientAPI). Consider updating for the latest features."
            showUpdateAlert = true
        case .compatible, .unknown, .checkFailed:
            break
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
