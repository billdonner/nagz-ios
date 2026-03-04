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
    @State private var wsTask: Task<Void, Never>?
    @State private var aiSummary: String?
    @State private var showAISummary = false
    @State private var generatingSummary = false
    @State private var scheduleNagId: UUID?
    @State private var showSchedulePicker = false
    @State private var collapsedSections: Set<String> = []
    @State private var hasSetDefaults = false
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

    /// Nags sent to me by other people
    private var nagsForMe: [NagResponse] {
        guard let userId = currentUserId else { return viewModel.nags }
        return viewModel.nags.filter { $0.recipientId == userId && $0.creatorId != userId }
    }

    /// Nags I sent to other people
    private var nagsForOthers: [NagResponse] {
        guard let userId = currentUserId else { return [] }
        return viewModel.nags.filter { $0.recipientId != userId }
    }

    /// Self-nags: I created them for myself
    private var selfNags: [NagResponse] {
        guard let userId = currentUserId else { return [] }
        return viewModel.nags.filter { $0.recipientId == userId && $0.creatorId == userId }
    }

    /// Group "For Me" nags by who sent them (counterpart = creator), sorted by committedAt ?? dueAt
    private var nagsForMeByCounterpart: [(name: String, nags: [NagResponse])] {
        let grouped = Dictionary(grouping: nagsForMe) { $0.creatorDisplayName ?? "Unknown" }
        return grouped.sorted { $0.key < $1.key }.map { group in
            let sorted = group.value.sorted { a, b in
                let aTime = a.committedAt ?? a.dueAt
                let bTime = b.committedAt ?? b.dueAt
                return aTime < bTime
            }
            return (name: group.key, nags: sorted)
        }
    }

    /// Group "Nagz to Others" by who they're for (counterpart = recipient)
    private var nagsForOthersByCounterpart: [(name: String, nags: [NagResponse])] {
        let grouped = Dictionary(grouping: nagsForOthers) { $0.recipientDisplayName ?? "Unknown" }
        return grouped.sorted { $0.key < $1.key }.map { (name: $0.key, nags: $0.value) }
    }

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
            CreateNagView(apiClient: viewModel.apiClient, familyId: familyId, currentUserId: currentUserId)
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
            // Reload when returning from detail view (e.g. after completing a nag)
            if !viewModel.nags.isEmpty {
                Task { await viewModel.loadNags() }
            }
            startWebSocket()
        }
        .onDisappear {
            stopWebSocket()
        }
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
            Task {
                await viewModel.loadNags()
                applyDefaultCollapse()
            }
        }
        .onChange(of: viewModel.nags.count) {
            if !hasSetDefaults && !viewModel.nags.isEmpty {
                hasSetDefaults = true
                applyDefaultCollapse()
            }
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.filter) {
            ForEach(NagFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading && viewModel.nags.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.nags.isEmpty {
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") { Task { await viewModel.loadNags() } }
            }
        } else if viewModel.nags.isEmpty {
            ContentUnavailableView {
                Label("No Nagz", systemImage: "checkmark.circle")
            } description: {
                VStack(spacing: 12) {
                    Text(viewModel.filter == .open ? "All caught up!" : "No nagz to show.")
                    SiriTipView(intent: CreateNagIntent(), isVisible: .constant(true))
                }
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
                    }
                )
            }
        }
    }

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
        }
        if canCreateNags {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateNag = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var nagList: some View {
        List {
            ForEach(nagsForMeByCounterpart, id: \.name) { group in
                CollapsibleNagSection(
                    title: "From \(group.name)",
                    count: group.nags.count,
                    nags: group.nags,
                    currentUserId: currentUserId,
                    isCollapsed: collapsedSections.contains("from:\(group.name)"),
                    onToggle: { toggleSection("from:\(group.name)") }
                )
            }

            ForEach(nagsForOthersByCounterpart, id: \.name) { group in
                CollapsibleNagSection(
                    title: "To \(group.name)",
                    count: group.nags.count,
                    nags: group.nags,
                    currentUserId: currentUserId,
                    isCollapsed: collapsedSections.contains("to:\(group.name)"),
                    onToggle: { toggleSection("to:\(group.name)") }
                )
            }

            if !selfNags.isEmpty {
                CollapsibleNagSection(
                    title: "My Reminders",
                    count: selfNags.count,
                    nags: selfNags,
                    currentUserId: currentUserId,
                    isCollapsed: collapsedSections.contains("self"),
                    onToggle: { toggleSection("self") },
                    icon: "pin.fill"
                )
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func toggleSection(_ key: String) {
        withAnimation {
            if collapsedSections.contains(key) {
                collapsedSections.remove(key)
            } else {
                collapsedSections.insert(key)
            }
        }
    }

    /// Set default collapsed state based on filter tab
    private func applyDefaultCollapse() {
        var collapsed = Set<String>()
        switch viewModel.filter {
        case .open:
            // Collapse "To" and "Self" sections, expand "From"
            for group in nagsForOthersByCounterpart {
                collapsed.insert("to:\(group.name)")
            }
            collapsed.insert("self")
        case .completed, .all:
            // Collapse everything
            for group in nagsForMeByCounterpart {
                collapsed.insert("from:\(group.name)")
            }
            for group in nagsForOthersByCounterpart {
                collapsed.insert("to:\(group.name)")
            }
            collapsed.insert("self")
        }
        collapsedSections = collapsed
    }

    private func startWebSocket() {
        guard let familyId, wsTask == nil else { return }
        wsTask = Task {
            let stream = await webSocketService.connect(familyId: familyId)
            for await event in stream {
                switch event.type {
                case .nagCreated, .nagUpdated, .nagStatusChanged, .excuseSubmitted:
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

    private func generateSummary() async {
        // Only summarize nags assigned to me — not ones I sent to others
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

// MARK: - Collapsible Section

private struct CollapsibleNagSection: View {
    let title: String
    let count: Int
    let nags: [NagResponse]
    let currentUserId: UUID?
    let isCollapsed: Bool
    let onToggle: () -> Void
    var icon: String? = nil

    var body: some View {
        Section {
            if !isCollapsed {
                ForEach(nags) { nag in
                    NavigationLink(value: nag.id) {
                        NagRowView(nag: nag, currentUserId: currentUserId)
                    }
                }
            }
        } header: {
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                    Text("(\(count))")
                        .foregroundStyle(.secondary)
                    UrgencySparkline(nags: nags)
                    Spacer()
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .textCase(nil)
        }
    }
}

// MARK: - Urgency Sparkline

private struct UrgencySparkline: View {
    let nags: [NagResponse]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(sortedPips.prefix(20).enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 3, height: 10)
            }
        }
    }

    private var sortedPips: [Color] {
        nags.map { pipColor(for: $0) }
            .sorted { $0.urgencyOrder < $1.urgencyOrder }
    }

    private func pipColor(for nag: NagResponse) -> Color {
        if nag.status == .completed { return .green }
        if nag.status == .missed { return .orange }
        guard nag.status == .open else { return .gray }
        let interval = nag.dueAt.timeIntervalSince(Date())
        if interval > 24 * 3600 { return .gray }
        if interval > 2 * 3600 { return .blue }
        if interval > 0 { return .yellow }
        return .orange
    }
}

private extension Color {
    var urgencyOrder: Int {
        switch self {
        case .red: 0
        case .orange: 1
        case .yellow: 2
        case .blue: 3
        case .green: 4
        default: 5
        }
    }
}
