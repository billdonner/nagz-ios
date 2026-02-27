import SwiftUI

/// Single-screen child UI — nag list + settings gear (no tabs).
struct ChildTabView: View {
    let authManager: AuthManager
    let apiClient: APIClient
    let syncService: SyncService
    let webSocketService: WebSocketService

    @State private var showSettings = false

    private var familyId: UUID? {
        guard let saved = UserDefaults.standard.string(forKey: "nagz_family_id") else { return nil }
        return UUID(uuidString: saved)
    }

    var body: some View {
        NavigationStack {
            ChildNagListView(
                apiClient: apiClient,
                familyId: familyId,
                currentUserId: authManager.currentUser?.id,
                webSocketService: webSocketService
            )
            .navigationTitle("My Nags")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            ChildSettingsView(
                authManager: authManager,
                apiClient: apiClient,
                familyId: familyId
            )
        }
        .task {
            if let familyId {
                await syncService.startPeriodicSync(familyId: familyId)
            }
        }
    }
}
