import SwiftUI

@main
struct NagzApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let keychainService: KeychainService
    private let apiClient: APIClient
    private let databaseManager: DatabaseManager?
    private let syncService: SyncService?
    private let aiService: (any AIService)?
    private let databaseError: String?
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

        // Local GRDB cache + sync
        var db: DatabaseManager?
        var sync: SyncService?
        var ai: (any AIService)?
        var dbError: String?
        do {
            let database = try DatabaseManager()
            db = database
            sync = SyncService(apiClient: api, db: database)

            // AI services: on-device with server fallback
            let serverAI = ServerAIService(apiClient: api)
            let onDeviceAI = OnDeviceAIService(db: database, fallback: serverAI)
            ai = onDeviceAI
        } catch {
            dbError = error.localizedDescription
        }

        self.keychainService = keychain
        self.apiClient = api
        self.databaseManager = db
        self.syncService = sync
        self.aiService = ai
        self.databaseError = dbError
        _authManager = State(initialValue: auth)
        _pushService = State(initialValue: push)
        _versionChecker = State(initialValue: checker)
    }

    var body: some Scene {
        WindowGroup {
            if let databaseError {
                DatabaseErrorView(errorMessage: databaseError)
            } else {
                ContentView(
                    authManager: authManager,
                    apiClient: apiClient,
                    pushService: pushService,
                    syncService: syncService!,
                    versionChecker: versionChecker
                )
                .environment(\.apiClient, apiClient)
                .onAppear {
                    appDelegate.pushService = pushService
                }
            }
        }
    }
}

struct DatabaseErrorView: View {
    let errorMessage: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("Storage Unavailable")
                .font(.title2.bold())
            Text("Nagz could not initialize its local storage. This may be caused by insufficient disk space or file corruption.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}
