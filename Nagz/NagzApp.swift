import SwiftUI

@main
struct NagzApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let keychainService: KeychainService
    private let apiClient: APIClient
    private let databaseManager: DatabaseManager
    private let syncService: SyncService
    private let aiService: any AIService
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
        let db: DatabaseManager
        do {
            db = try DatabaseManager()
        } catch {
            fatalError("Failed to initialize database: \(error.localizedDescription)")
        }
        let sync = SyncService(apiClient: api, db: db)

        // AI services: on-device with server fallback
        let serverAI = ServerAIService(apiClient: api)
        let onDeviceAI = OnDeviceAIService(db: db, fallback: serverAI)

        self.keychainService = keychain
        self.apiClient = api
        self.databaseManager = db
        self.syncService = sync
        self.aiService = onDeviceAI
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
