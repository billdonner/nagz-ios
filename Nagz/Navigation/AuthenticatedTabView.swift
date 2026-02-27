import SwiftUI
import AppIntents

struct AuthenticatedTabView: View {
    let authManager: AuthManager
    let apiClient: APIClient
    let pushService: PushNotificationService
    let syncService: SyncService
    let webSocketService: WebSocketService

    @State private var familyViewModel: FamilyViewModel
    @State private var nagNavigationPath = NavigationPath()

    init(authManager: AuthManager, apiClient: APIClient, pushService: PushNotificationService, syncService: SyncService, webSocketService: WebSocketService) {
        self.authManager = authManager
        self.apiClient = apiClient
        self.pushService = pushService
        self.syncService = syncService
        self.webSocketService = webSocketService
        _familyViewModel = State(initialValue: FamilyViewModel(apiClient: apiClient))
    }

    private var currentUserId: UUID {
        guard let user = authManager.currentUser else {
            DebugLogger.shared.log("AuthenticatedTabView shown without authenticated user", level: .warning)
            return UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        }
        return user.id
    }

    private var myRole: FamilyRole? {
        familyViewModel.members.first(where: { $0.userId == currentUserId })?.role
    }

    private var isGuardian: Bool {
        myRole == .guardian || authManager.currentRole == .guardian
    }

    private var canCreateNags: Bool {
        // Can always create nags (connection nags don't require family role)
        // Family nags still require guardian/participant role
        true
    }

    @AppStorage("selectedTab") private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            nagsTab
                .tag(0)
            peopleTab
                .tag(1)
            familyTab
                .tag(2)
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
            NagListView(
                apiClient: apiClient,
                familyId: familyViewModel.family?.familyId,
                canCreateNags: canCreateNags,
                currentUserId: authManager.currentUser?.id,
                webSocketService: webSocketService
            )
            .navigationDestination(for: UUID.self) { nagId in
                NagDetailView(apiClient: apiClient, nagId: nagId, currentUserId: currentUserId, isGuardian: isGuardian)
            }
        }
        .tabItem {
            Label("Nagz", systemImage: "bell.fill")
        }
    }

    private var peopleTab: some View {
        NavigationStack {
            ConnectionListView(apiClient: apiClient)
        }
        .tabItem {
            Label("People", systemImage: "person.2.fill")
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

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    static var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let family = viewModel.family {
                List {
                    Section("Family") {
                        LabeledContent("Name", value: family.name)
                        if isAdmin {
                            NavigationLink("Members") {
                                ManageMembersView(apiClient: apiClient, familyId: family.familyId, childCode: family.childCode)
                            }
                        } else {
                            NavigationLink("Members") {
                                MemberListView(apiClient: apiClient, familyId: family.familyId)
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

                    if isAdmin {
                        Section("AI Insights") {
                            NavigationLink("Family Insights") {
                                FamilyInsightsView(familyId: family.familyId, currentUserId: currentUserId)
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

                    Section {
                        Text("\(authManager.currentUser?.email ?? "—") \u{2022} v\(Self.appVersion) (\(Self.appBuild))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
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

                    Text("\(authManager.currentUser?.email ?? "—") \u{2022} v\(Self.appVersion) (\(Self.appBuild))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
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
