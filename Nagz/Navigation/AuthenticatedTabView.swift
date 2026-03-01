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
            ConnectionListView(
                apiClient: apiClient,
                familyId: familyViewModel.family?.familyId,
                currentUserId: authManager.currentUser?.id,
                webSocketService: webSocketService
            )
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
    @Environment(\.aiService) private var aiService
    @State private var digest: DigestResponse?
    @State private var showOnboarding = false

    private func memberColor(for role: FamilyRole) -> Color {
        switch role {
        case .guardian: .blue
        case .participant: .orange
        case .child: .green
        }
    }

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
                    // Inline AI digest at top when there's useful data
                    if let digest, digest.totals.totalNags > 0 {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.purple)
                                    Text("This Week")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    NavigationLink {
                                        FamilyInsightsView(familyId: family.familyId, currentUserId: currentUserId)
                                    } label: {
                                        Text("Details")
                                            .font(.caption)
                                    }
                                }

                                Text(digest.summaryText)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 0) {
                                    digestStat(value: digest.totals.completed, label: "Done", color: .green)
                                    Spacer()
                                    digestStat(value: digest.totals.open, label: "Open", color: .blue)
                                    Spacer()
                                    digestStat(value: digest.totals.missed, label: "Missed", color: .red)
                                    Spacer()
                                    Text("\(Int(digest.totals.completionRate * 100))%")
                                        .font(.title3.weight(.bold).monospacedDigit())
                                        .foregroundStyle(digest.totals.completionRate >= 0.7 ? .green : .orange)
                                }
                            }
                        }
                    }

                    // Family members as horizontal scroll
                    if !viewModel.members.isEmpty {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(viewModel.members.filter { $0.status != .removed }) { member in
                                        VStack(spacing: 6) {
                                            ZStack(alignment: .bottomTrailing) {
                                                Text(String((member.displayName ?? "?").prefix(1)).uppercased())
                                                    .font(.title3.weight(.bold))
                                                    .foregroundStyle(.white)
                                                    .frame(width: 52, height: 52)
                                                    .background(memberColor(for: member.role))
                                                    .clipShape(Circle())

                                                if member.userId == currentUserId {
                                                    Circle()
                                                        .fill(.blue)
                                                        .frame(width: 16, height: 16)
                                                        .overlay {
                                                            Image(systemName: "star.fill")
                                                                .font(.system(size: 8))
                                                                .foregroundStyle(.white)
                                                        }
                                                }
                                            }

                                            Text(member.displayName ?? "?")
                                                .font(.caption)
                                                .lineLimit(1)
                                                .frame(width: 64)

                                            Text(member.role.rawValue.capitalized)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            if isAdmin {
                                NavigationLink {
                                    ManageMembersView(apiClient: apiClient, familyId: family.familyId, childCode: family.childCode)
                                } label: {
                                    Label("Manage Members", systemImage: "person.badge.plus")
                                }
                            } else {
                                NavigationLink {
                                    MemberListView(apiClient: apiClient, familyId: family.familyId)
                                } label: {
                                    Label("All Members", systemImage: "person.2")
                                }
                            }
                        } header: {
                            Text("\(viewModel.members.filter { $0.status != .removed }.count) Members")
                        }
                    } else {
                        Section("Family") {
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
                                .font(.system(.title3, design: .monospaced).weight(.semibold))
                            Spacer()
                            Button {
                                UIPasteboard.general.string = family.inviteCode
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                        ShareLink(
                            item: "Join our family \"\(family.name)\" on Nagz! Use invite code: \(family.inviteCode)",
                            subject: Text("Join \(family.name) on Nagz"),
                            message: Text("Use this code to join our family in the Nagz app.")
                        ) {
                            Label("Send Invite", systemImage: "square.and.arrow.up")
                        }
                    }


                    Section {
                        Button {
                            showOnboarding = true
                        } label: {
                            Label("What's New in Nagz", systemImage: "sparkles")
                        }
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
                .onAppear {
                    Task { await viewModel.loadFamily(id: family.familyId) }
                    Task { await loadDigest(familyId: family.familyId) }
                }
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
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isRerun: true)
        }
    }

    private func loadDigest(familyId: UUID) async {
        guard let aiService else { return }
        do {
            let d = try await aiService.digest(familyId: familyId)
            if d.totals.totalNags > 0 {
                digest = d
            }
        } catch {
            // Non-critical — just don't show the card
        }
    }

    private func digestStat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
