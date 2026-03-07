import SwiftUI
import AppIntents
import MessageUI
import NagzAI

private struct NotificationItem: Identifiable {
    let id: UUID
}

struct AuthenticatedTabView: View {
    let authManager: AuthManager
    let apiClient: APIClient
    let pushService: PushNotificationService
    let syncService: SyncService
    let webSocketService: WebSocketService

    @State private var familyViewModel: FamilyViewModel

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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            #if canImport(FoundationModels)
            if NagzAI.Router.isAppleIntelligenceAvailable {
                chatTab
                    .tag(0)
            }
            #endif
            nagsTab
                .tag(1)
            peopleTab
                .tag(2)
            settingsTab
                .tag(3)
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
                selectedTab = 1
                pushService.notificationNagId = nagId
                pushService.clearPendingNag()
            }
        }
        .onChange(of: pushService.pendingNagId) { _, newValue in
            if let nagId = newValue {
                selectedTab = 1
                pushService.notificationNagId = nagId
                pushService.clearPendingNag()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, let nagId = pushService.pendingNagId {
                selectedTab = 1
                pushService.notificationNagId = nagId
                pushService.clearPendingNag()
            }
        }
        .fullScreenCover(item: Binding(
            get: { pushService.notificationNagId.map { NotificationItem(id: $0) } },
            set: { if $0 == nil { pushService.notificationNagId = nil } }
        )) { item in
            NavigationStack {
                NagDetailView(
                    apiClient: apiClient,
                    nagId: item.id,
                    currentUserId: currentUserId,
                    isGuardian: isGuardian
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { pushService.notificationNagId = nil }
                    }
                }
            }
        }
    }

    private var nagsTab: some View {
        @Bindable var ps = pushService
        return NavigationStack(path: $ps.nagNavigationPath) {
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
                webSocketService: webSocketService,
                userName: authManager.currentUser?.displayName
            )
        }
        .tabItem {
            Label("People", systemImage: "person.2.fill")
        }
    }

    #if canImport(FoundationModels)
    @ViewBuilder
    private var chatTab: some View {
        NavigationStack {
            GlobalChatView(
                apiClient: apiClient,
                currentUserId: currentUserId,
                familyId: familyViewModel.family?.familyId,
                userName: authManager.currentUser?.displayName ?? authManager.currentUser?.email ?? "User",
                familyName: familyViewModel.family?.name,
                memberNames: familyViewModel.members
                    .filter { $0.status != .removed }
                    .compactMap(\.displayName)
            )
        }
        .tabItem {
            Label("Chat", systemImage: "ellipsis.message.fill")
        }
    }
    #endif

    private var settingsTab: some View {
        NavigationStack {
            SettingsTabContent(
                viewModel: familyViewModel,
                apiClient: apiClient,
                authManager: authManager,
                isAdmin: isGuardian,
                currentUserId: currentUserId
            )
        }
        .tabItem {
            Label("Settings", systemImage: "gearshape.fill")
        }
    }
}

// MARK: - Settings Tab

private struct SettingsTabContent: View {
    @Bindable var viewModel: FamilyViewModel
    let apiClient: APIClient
    let authManager: AuthManager
    let isAdmin: Bool
    let currentUserId: UUID

    @AppStorage("nagz_ai_personality") private var personalityRaw: String = AIPersonality.standard.rawValue
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isExporting = false
    @State private var showExportSuccess = false
    @State private var errorMessage: String?
    @State private var showFeedbackMail = false
    @State private var showMailUnavailableAlert = false
    @State private var showOnboarding = false
    @State private var serverReachable: Bool? = nil

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    static var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    var body: some View {
        List {
            Section("Account") {
                if let email = authManager.currentUser?.email {
                    LabeledContent("Email", value: email)
                }
            }

            if NagzAI.Router.isAppleIntelligenceAvailable {
                Section {
                    Picker("AI Personality", selection: $personalityRaw) {
                        ForEach(AIPersonality.allCases, id: \.rawValue) { personality in
                            VStack(alignment: .leading) {
                                Text(personality.displayName)
                                Text(personality.tagline)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(personality.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("AI Personality")
                } footer: {
                    Text("Choose the style of AI-generated coaching, nudges, and summaries.")
                }
            }

            Section("Family") {
                NavigationLink {
                    FamilyTabContent(
                        viewModel: viewModel,
                        apiClient: apiClient,
                        isAdmin: isAdmin,
                        currentUserId: currentUserId
                    )
                } label: {
                    Label {
                        if let family = viewModel.family {
                            Text(family.name)
                        } else {
                            Text("Create or Join Family")
                        }
                    } icon: {
                        Image(systemName: "person.3.fill")
                    }
                }
            }

            if let family = viewModel.family {
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
            }

            Section("Safety") {
                NavigationLink {
                    SafetyView(
                        apiClient: apiClient,
                        members: viewModel.members,
                        currentUserId: currentUserId,
                        isGuardian: isAdmin
                    )
                } label: {
                    Label("Safety", systemImage: "shield.fill")
                }
            }

            Section("Legal") {
                NavigationLink {
                    LegalDocumentView(apiClient: apiClient, documentType: .privacyPolicy)
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }
                NavigationLink {
                    LegalDocumentView(apiClient: apiClient, documentType: .termsOfService)
                } label: {
                    Label("Terms of Service", systemImage: "doc.text.fill")
                }
            }

            Section("Feedback") {
                Button {
                    if MFMailComposeViewController.canSendMail() {
                        showFeedbackMail = true
                    } else {
                        showMailUnavailableAlert = true
                    }
                } label: {
                    Label("Report an Issue", systemImage: "envelope.fill")
                }
            }

            Section {
                Button {
                    Task { await exportData() }
                } label: {
                    HStack {
                        Label("Export My Data", systemImage: "square.and.arrow.up")
                        Spacer()
                        if isExporting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isExporting)

                Button("Delete My Account", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .disabled(isDeleting)
            } header: {
                Text("Your Data")
            } footer: {
                Text("Export downloads a copy of all your personal data (GDPR/CCPA). Deleting your account is permanent and cannot be undone.")
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
                VStack(spacing: 4) {
                    Text("v\(Self.appVersion) (\(Self.appBuild))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currentUserId.uuidString.prefix(8) + "...")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                    Text(AppEnvironment.current.baseURL.absoluteString)
                        .font(.caption2.monospaced())
                        .foregroundStyle(serverReachable == true ? Color.green : serverReachable == false ? Color.red : Color(uiColor: .tertiaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
            }

            if let error = errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            let url = AppEnvironment.current.baseURL.appendingPathComponent("metrics")
            serverReachable = await (try? URLSession.shared.data(from: url)) != nil
        }
        .alert("Export Complete", isPresented: $showExportSuccess) {
            Button("OK") {}
        } message: {
            Text("Your data export has been prepared. You will receive it shortly.")
        }
        .sheet(isPresented: $showFeedbackMail) {
            MailComposeView(
                recipient: Constants.Feedback.email,
                subject: "Nagz Feedback \u{2014} \(Self.appVersion)",
                body: "Please describe the issue:\n\n\n---\n\(DeviceDiagnostics.summary)",
                attachmentData: DebugLogger.shared.logFileData(),
                attachmentFilename: "nagz_debug.log"
            )
        }
        .alert("Mail Unavailable", isPresented: $showMailUnavailableAlert) {
            Button("Copy Info") {
                UIPasteboard.general.string = DeviceDiagnostics.summary
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Mail is not configured on this device. Tap 'Copy Info' to copy device diagnostics to the clipboard, then paste into your preferred email app and send to \(Constants.Feedback.email).")
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete My Account", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Are you sure? This permanently deletes your account and all associated data. This cannot be undone.")
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isRerun: true)
        }
    }

    private func exportData() async {
        isExporting = true
        errorMessage = nil
        do {
            let _: [String: AnyCodableValue] = try await apiClient.request(.exportAccountData())
            showExportSuccess = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isExporting = false
    }

    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil
        do {
            let _: AccountResponse = try await apiClient.request(
                .deleteAccount(userId: currentUserId)
            )
            await authManager.logout()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}

// MARK: - Family Management (push destination from Settings)

private struct FamilyTabContent: View {
    @Bindable var viewModel: FamilyViewModel
    let apiClient: APIClient
    let isAdmin: Bool
    let currentUserId: UUID
    @Environment(\.aiService) private var aiService
    @State private var digest: DigestResponse?
    @AppStorage("hasSeenFamilyIntro") private var hasSeenFamilyIntro = false
    @State private var showFamilyIntro = false
    @State private var showLeaveConfirmation = false
    @State private var isLeaving = false
    @State private var leaveError: String?

    private func memberColor(for role: FamilyRole) -> Color {
        switch role {
        case .guardian: .blue
        case .participant: .orange
        case .child: .green
        }
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
                        Section("Family Settings") {
                            NavigationLink("Family Preferences") {
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
                        Button(role: .destructive) {
                            showLeaveConfirmation = true
                        } label: {
                            Label("Leave Family", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } footer: {
                        Text("Your open nags in this family will be cancelled. You can rejoin with an invite code.")
                    }
                }
                .navigationTitle(family.name)
                .onAppear {
                    Task { await viewModel.loadFamily(id: family.familyId) }
                    Task { await loadDigest(familyId: family.familyId) }
                }
            } else {
                VStack(spacing: 20) {
                    Text("Family (Optional)")
                        .font(.title2.weight(.semibold))

                    Text("You don't need a family to use Nagz. You can nag friends and colleagues directly via the People tab — no family required.\n\nSet up a family only if you want to nag children or share tasks with household members.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Create Family") {
                        viewModel.showCreateSheet = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Join Family") {
                        viewModel.showJoinSheet = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .navigationTitle("Family")
            }
        }
        .onAppear {
            if viewModel.family != nil && !hasSeenFamilyIntro {
                showFamilyIntro = true
            }
        }
        .confirmationDialog(
            "Leave Family?",
            isPresented: $showLeaveConfirmation
        ) {
            Button("Leave", role: .destructive) {
                guard let familyId = viewModel.family?.familyId else { return }
                Task {
                    isLeaving = true
                    do {
                        let _: MemberResponse = try await apiClient.request(.leaveFamily(familyId: familyId))
                        viewModel.family = nil
                        viewModel.members = []
                    } catch let error as APIError {
                        leaveError = error.errorDescription
                    } catch {
                        leaveError = error.localizedDescription
                    }
                    isLeaving = false
                }
            }
        } message: {
            Text("Your open nags will be cancelled and you'll be removed from this family. You can rejoin later with an invite code.")
        }
        .alert("Cannot Leave", isPresented: Binding(get: { leaveError != nil }, set: { if !$0 { leaveError = nil } })) {
            Button("OK") { leaveError = nil }
        } message: {
            Text(leaveError ?? "")
        }
        .sheet(isPresented: $showFamilyIntro) {
            NavigationStack {
                OnboardingPageView(
                    page: OnboardingPage(
                        symbol: "person.3.fill",
                        color: .purple,
                        title: "Your Family Hub",
                        subtitle: "Manage your family members, share invite codes, view the weekly AI digest, configure preferences, and access the guardian dashboard — all right here.",
                        supportingIcons: [
                            ("person.badge.plus", "Members"),
                            ("sparkles", "Digest"),
                            ("shield.fill", "Guardian"),
                            ("square.and.arrow.up", "Invite"),
                        ]
                    ),
                    isLastPage: true,
                    buttonTitle: "Got It",
                    onGetStarted: {
                        hasSeenFamilyIntro = true
                        showFamilyIntro = false
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Skip") {
                            hasSeenFamilyIntro = true
                            showFamilyIntro = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateFamilyView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showJoinSheet) {
            JoinFamilyView(viewModel: viewModel)
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
