import SwiftUI
import AppIntents

struct AuthenticatedTabView: View {
    let authManager: AuthManager
    let apiClient: APIClient
    let pushService: PushNotificationService
    let syncService: SyncService

    @State private var familyViewModel: FamilyViewModel
    @State private var nagNavigationPath = NavigationPath()

    init(authManager: AuthManager, apiClient: APIClient, pushService: PushNotificationService, syncService: SyncService) {
        self.authManager = authManager
        self.apiClient = apiClient
        self.pushService = pushService
        self.syncService = syncService
        _familyViewModel = State(initialValue: FamilyViewModel(apiClient: apiClient))
    }

    private var currentUserId: UUID {
        guard let user = authManager.currentUser else {
            // Log the error — assertionFailure is stripped in Release
            print("WARNING: AuthenticatedTabView shown without authenticated user")
            return UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        }
        return user.id
    }

    private var myRole: FamilyRole? {
        familyViewModel.members.first(where: { $0.userId == currentUserId })?.role
    }

    private var isGuardian: Bool {
        myRole == .guardian
    }

    private var canCreateNags: Bool {
        myRole?.canCreateNags ?? false
    }

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            nagsTab
                .tag(0)
            familyTab
                .tag(1)
        }
        .task {
            pushService.requestPermissionAndRegister()
            if familyViewModel.family == nil,
               let savedId = UserDefaults.standard.string(forKey: "nagz_family_id"),
               let familyId = UUID(uuidString: savedId) {
                await familyViewModel.loadFamily(id: familyId)
                await syncService.startPeriodicSync(familyId: familyId)
            }
            NagzShortcutsProvider.updateAppShortcutParameters()
            // Restore any pending nag from cold start (persisted to UserDefaults)
            pushService.restorePendingNag()
            if let nagId = pushService.pendingNagId {
                selectedTab = 0
                nagNavigationPath.append(nagId)
                pushService.clearPendingNag()
            }
        }
        .onChange(of: pushService.pendingNagId) { _, newValue in
            if let nagId = newValue {
                selectedTab = 0
                nagNavigationPath.append(nagId)
                pushService.clearPendingNag()
            }
        }
    }

    private var nagsTab: some View {
        NavigationStack(path: $nagNavigationPath) {
            if let family = familyViewModel.family {
                NagListView(apiClient: apiClient, familyId: family.familyId, canCreateNags: canCreateNags)
                    .navigationDestination(for: UUID.self) { nagId in
                        NagDetailView(apiClient: apiClient, nagId: nagId, currentUserId: currentUserId, isGuardian: isGuardian)
                    }
            } else {
                ContentUnavailableView {
                    Label("No Family", systemImage: "house")
                } description: {
                    Text("Create or join a family first.")
                }
            }
        }
        .tabItem {
            Label("Nags", systemImage: "bell.fill")
        }
    }

    private var familyTab: some View {
        NavigationStack {
            FamilyTabContent(
                viewModel: familyViewModel,
                apiClient: apiClient,
                authManager: authManager,
                isAdmin: isGuardian,
                currentUserId: currentUserId
            )
        }
        .tabItem {
            Label("Family", systemImage: "person.3.fill")
        }
    }
}

private struct FamilyTabContent: View {
    @Bindable var viewModel: FamilyViewModel
    let apiClient: APIClient
    let authManager: AuthManager
    let isAdmin: Bool
    let currentUserId: UUID

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let family = viewModel.family {
                List {
                    Section("Family") {
                        LabeledContent("Name", value: family.name)
                        NavigationLink("Members") {
                            MemberListView(apiClient: apiClient, familyId: family.familyId)
                        }
                        if isAdmin {
                            NavigationLink("Manage Members") {
                                ManageMembersView(apiClient: apiClient, familyId: family.familyId)
                            }
                        }
                    }

                    if isAdmin {
                        Section("Settings") {
                            NavigationLink("Preferences") {
                                PreferencesView(apiClient: apiClient, familyId: family.familyId)
                            }
                            NavigationLink("Consents") {
                                ConsentListView(apiClient: apiClient, familyId: family.familyId)
                            }
                        }

                        Section("Guardian Dashboard") {
                            NavigationLink("Reports") {
                                ReportsView(apiClient: apiClient, familyId: family.familyId)
                            }
                            NavigationLink("Policies") {
                                PolicyListView(apiClient: apiClient, familyId: family.familyId, members: viewModel.members)
                            }
                        }
                    }

                    Section("Gamification") {
                        NavigationLink("Points & Streaks") {
                            GamificationView(
                                apiClient: apiClient,
                                familyId: family.familyId,
                                userId: currentUserId,
                                members: viewModel.members
                            )
                        }
                        if isAdmin {
                            NavigationLink("Incentive Rules") {
                                IncentiveRulesView(apiClient: apiClient, familyId: family.familyId)
                            }
                        }
                    }

                    Section("Safety & Account") {
                        NavigationLink("Safety") {
                            SafetyView(
                                apiClient: apiClient,
                                members: viewModel.members,
                                currentUserId: currentUserId,
                                isGuardian: isAdmin
                            )
                        }
                        NavigationLink("Account") {
                            AccountView(
                                apiClient: apiClient,
                                authManager: authManager,
                                currentUserId: currentUserId
                            )
                        }
                    }

                    Section("Invite Code") {
                        HStack {
                            Text(family.inviteCode)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                UIPasteboard.general.string = family.inviteCode
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                        Text("Share this code with family members so they can join.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Button("Log Out", role: .destructive) {
                            Task { await authManager.logout() }
                        }
                    }
                }
                .navigationTitle(family.name)
            } else {
                VStack(spacing: 20) {
                    Text("Welcome to Nagz!")
                        .font(.title2.weight(.semibold))

                    Text("Create a family or join an existing one to get started.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Create Family") {
                        viewModel.showCreateSheet = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Join Family") {
                        viewModel.showJoinSheet = true
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Log Out", role: .destructive) {
                        Task { await authManager.logout() }
                    }
                }
                .padding()
                .navigationTitle("Family")
            }
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateFamilyView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showJoinSheet) {
            JoinFamilyView(viewModel: viewModel)
        }
    }
}
