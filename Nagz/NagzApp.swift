import SwiftUI

@main
struct NagzApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let keychainService: KeychainService
    private let apiClient: APIClient
    @State private var authManager: AuthManager
    @State private var pushService: PushNotificationService
    @State private var versionChecker: VersionChecker

    init() {
        let keychain = KeychainService()
        let api = APIClient(keychainService: keychain)
        let auth = AuthManager(apiClient: api, keychainService: keychain)
        let push = PushNotificationService()
        push.configure(apiClient: api)
        let checker = VersionChecker(apiClient: api)

        self.keychainService = keychain
        self.apiClient = api
        _authManager = State(initialValue: auth)
        _pushService = State(initialValue: push)
        _versionChecker = State(initialValue: checker)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                authManager: authManager,
                apiClient: apiClient,
                pushService: pushService,
                versionChecker: versionChecker
            )
            .environment(\.apiClient, apiClient)
            .onAppear {
                appDelegate.pushService = pushService
            }
        }
    }
}
