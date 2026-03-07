import SwiftUI
import NagzAI
import AppIntents

private enum ViewMode: String {
    case list, schedule
}

struct NagListView: View {
    @State var viewModel: NagListViewModel
    let canCreateNags: Bool
    let familyId: UUID?
    let currentUserId: UUID?
    let webSocketService: WebSocketService
    @State private var viewMode: ViewMode = .list
    @State private var showCreateNag = false
    @State private var createNagDate: Date? = nil
    @State private var wsTask: Task<Void, Never>?
    @State private var aiSummary: String?
    @State private var showAISummary = false
    @State private var generatingSummary = false
    @State private var scheduleNagId: UUID?
    @State private var showSchedulePicker = false
    @State private var assignedCollapsed = true
    @AppStorage("nagz_ai_personality") private var personalityRaw: String = AIPersonality.standard.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init(apiClient: APIClient, familyId: UUID?, canCreateNags: Bool, currentUserId: UUID? = nil, webSocketService: WebSocketService) {
        let vm = NagListViewModel(apiClient: apiClient)
        _viewModel = State(initialValue: vm)
        self.familyId = familyId
        self.canCreateNags = canCreateNags
        self.currentUserId = currentUserId
        self.webSocketService = webSocketService
    }

    // MARK: - Computed splits

    /// Nags sent to me by others
    private var nagsForMe: [NagResponse] {
        guard let userId = currentUserId else { return viewModel.nags }
        return viewModel.nags.filter { $0.recipientId == userId && $0.creatorId != userId }
    }

    /// Nags I sent to other people
    private var nagsForOthers: [NagResponse] {
        guard let userId = currentUserId else { return [] }
        return viewModel.nags.filter { $0.recipientId != userId }
    }

    /// Self-nags
    private var selfNags: [NagResponse] {
        guard let userId = currentUserId else { return [] }
        return viewModel.nags.filter { $0.recipientId == userId && $0.creatorId == userId }
    }

    /// "Your List" — nags you need to act on, auto-fading completed > 24h old
    private var myItems: [NagResponse] {
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        let items = (nagsForMe + selfNags).filter { nag in
            if nag.status == .completed, let completedAt = nag.completedAt {
                return completedAt > cutoff
            }
            return true
        }
        return items.sorted { a, b in
            let aTime = a.committedAt ?? a.dueAt
            let bTime = b.committedAt ?? b.dueAt
            return aTime < bTime
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            filterPicker
            contentArea
        }
        .navigationTitle("Nagz")
        .toolbar { nagToolbar }
        .sheet(isPresented: $showAISummary) {
            AISummarySheet(
                nags: viewModel.nags,
                currentUserId: currentUserId,
                summaryText: aiSummary ?? "",
                filterLabel: viewModel.filter.rawValue
            )
        }
        .sheet(isPresented: $showCreateNag) {
            Task { await viewModel.loadNags() }
        } content: {
            CreateNagView(apiClient: viewModel.apiClient, familyId: familyId, currentUserId: currentUserId, preselectedDate: createNagDate)
        }
        .sheet(isPresented: $showSchedulePicker) {
            CommitTimePickerSheet { date in
                if let nagId = scheduleNagId {
                    Task {
                        let update = NagUpdate(committedAt: date)
                        let _: NagResponse = try await viewModel.apiClient.request(
                            .updateNag(nagId: nagId, update: update)
                        )
                        await viewModel.loadNags()
                    }
                }
                showSchedulePicker = false
            }
        }
        .task {
            viewModel.setFamily(familyId)
            await viewModel.loadNags()
        }
        .onAppear {
            startWebSocket()
        }
        .onDisappear { stopWebSocket() }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task { await viewModel.loadNags() }
                startWebSocket()
            } else {
                stopWebSocket()
            }
        }
        .refreshable { await viewModel.refresh() }
        .onChange(of: viewModel.filter) {
            Task { await viewModel.loadNags() }
        }
    }

    // MARK: - Filter picker

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.filter) {
            ForEach(NagFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.loadState.isIdle || (viewModel.loadState.isLoading && viewModel.nags.isEmpty) {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.loadState.error, viewModel.nags.isEmpty {
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Retry") { Task { await viewModel.loadNags() } }
            }
        } else if viewMode == .list {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                nagList
            }
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                DayPlannerView(
                    nags: viewModel.nags,
                    currentUserId: currentUserId,
                    onCommit: { nagId, date in
                        Task {
                            let update = NagUpdate(committedAt: date)
                            let _: NagResponse = try await viewModel.apiClient.request(
                                .updateNag(nagId: nagId, update: update)
                            )
                            await viewModel.loadNags()
                        }
                    },
                    onUncommit: { nagId in
                        Task {
                            let update = NagUpdate(clearCommittedAt: true)
                            let _: NagResponse = try await viewModel.apiClient.request(
                                .updateNag(nagId: nagId, update: update)
                            )
                            await viewModel.loadNags()
                        }
                    },
                    onCreateAtTime: { date in
                        createNagDate = date
                        showCreateNag = true
                    },
                    onCreateForDay: { date in
                        createNagDate = date
                        showCreateNag = true
                    }
                )
            }
        }
    }

    // MARK: - Nag list (flat Your List + collapsed You Assigned)

    private var nagList: some View {
        List {
            // YOUR LIST
            Section {
                if myItems.isEmpty {
                    if viewModel.filter == .open {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                Text("All caught up!")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(myItems) { nag in
                        NavigationLink(value: nag.id) {
                            DoerNagRowView(nag: nag, currentUserId: currentUserId)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if nag.status == .open, let userId = currentUserId,
                               nag.recipientId == userId, nag.creatorId != userId {
                                Button {
                                    swipeDismiss(nag)
                                } label: {
                                    Label("Dismiss", systemImage: "eye.slash")
                                }
                                .tint(.gray)
                            }
                        }
                    }
                }
            } header: {
                Text("Your List")
                    .font(.headline.weight(.semibold))
                    .textCase(nil)
                    .foregroundStyle(.primary)
            }

            // YOU ASSIGNED (collapsible)
            if !nagsForOthers.isEmpty {
                Section {
                    if !assignedCollapsed {
                        ForEach(nagsForOthers) { nag in
                            NavigationLink(value: nag.id) {
                                AssignedNagRowView(nag: nag)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if nag.status == .open {
                                    Button(role: .destructive) {
                                        swipeWithdraw(nag)
                                    } label: {
                                        Label("Withdraw", systemImage: "arrow.uturn.backward")
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Button {
                        withAnimation { assignedCollapsed.toggle() }
                    } label: {
                        HStack {
                            Text("You Assigned (\(nagsForOthers.count))")
                                .font(.subheadline)
                                .textCase(nil)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: assignedCollapsed ? "chevron.right" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.isLoadingMore {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var nagToolbar: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        if NagzAI.Router.isAppleIntelligenceAvailable {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    generatingSummary = true
                    Task {
                        await generateSummary()
                        generatingSummary = false
                    }
                } label: {
                    if generatingSummary {
                        ProgressView()
                    } else {
                        Image(systemName: "sparkles")
                    }
                }
                .disabled(viewModel.nags.isEmpty || generatingSummary)
                .accessibilityLabel("AI Summary")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withAnimation {
                    viewMode = viewMode == .list ? .schedule : .list
                }
            } label: {
                Image(systemName: viewMode == .list ? "calendar" : "list.bullet")
            }
            .accessibilityLabel(viewMode == .list ? "Schedule View" : "List View")
        }
        if canCreateNags {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNagDate = nil
                    showCreateNag = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create Nag")
            }
        }
    }

    // MARK: - Swipe actions

    private func swipeWithdraw(_ nag: NagResponse) {
        Task {
            let _: NagResponse = try await viewModel.apiClient.request(.withdrawNag(nagId: nag.id))
            await viewModel.loadNags()
        }
    }

    private func swipeDismiss(_ nag: NagResponse) {
        Task {
            let _: NagResponse = try await viewModel.apiClient.request(.dismissNag(nagId: nag.id))
            await viewModel.loadNags()
        }
    }

    // MARK: - WebSocket

    private func startWebSocket() {
        guard let familyId, wsTask == nil else { return }
        wsTask = Task {
            let stream = await webSocketService.connect(familyId: familyId)
            for await event in stream {
                switch event.type {
                case .nagCreated, .nagUpdated, .nagStatusChanged, .nagWithdrawn, .excuseSubmitted:
                    await viewModel.loadNags()
                case .memberAdded, .memberRemoved, .connectionInvited, .connectionAccepted:
                    break
                case .ping, .pong:
                    break
                }
            }
        }
    }

    private func stopWebSocket() {
        wsTask?.cancel()
        wsTask = nil
        Task { await webSocketService.disconnect() }
    }

    // MARK: - AI Summary

    private func generateSummary() async {
        let visibleNags = nagsForMe
        let items = visibleNags.map { nag in
            NagSummaryItem(
                category: nag.category.rawValue,
                status: nag.status.rawValue,
                dueAt: nag.dueAt,
                description: nag.description
            )
        }
        let filterStatus: String? = viewModel.filter == .all ? nil : viewModel.filter.nagStatus?.rawValue
        let personality = AIPersonality(rawValue: personalityRaw) ?? .standard
        let context = ListSummaryContext(nags: items, filterStatus: filterStatus, isChild: false, personality: personality)
        do {
            let result = try await NagzAI.Router().listSummary(context: context)
            aiSummary = result.summary
            showAISummary = true
        } catch {
            aiSummary = "Couldn't generate summary."
            showAISummary = true
        }
    }
}
