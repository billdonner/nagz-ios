import SwiftUI
import NagzAI

struct NagListView: View {
    @State var viewModel: NagListViewModel
    let canCreateNags: Bool
    let familyId: UUID?
    let currentUserId: UUID?
    let webSocketService: WebSocketService
    @State private var showCreateNag = false
    @State private var wsTask: Task<Void, Never>?
    @State private var aiSummary: String?
    @State private var showAISummary = false
    @State private var generatingSummary = false
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

    private var nagsForMe: [NagResponse] {
        guard let userId = currentUserId else { return viewModel.nags }
        return viewModel.nags.filter { $0.recipientId == userId }
    }

    private var nagsForOthers: [NagResponse] {
        guard let userId = currentUserId else { return [] }
        return viewModel.nags.filter { $0.recipientId != userId }
    }

    /// Group "For Me" nags by who sent them (counterpart = creator)
    private var nagsForMeByCounterpart: [(name: String, nags: [NagResponse])] {
        let grouped = Dictionary(grouping: nagsForMe) { $0.creatorDisplayName ?? "Unknown" }
        return grouped.sorted { $0.key < $1.key }.map { (name: $0.key, nags: $0.value) }
    }

    /// Group "Nagz to Others" by who they're for (counterpart = recipient)
    private var nagsForOthersByCounterpart: [(name: String, nags: [NagResponse])] {
        let grouped = Dictionary(grouping: nagsForOthers) { $0.recipientDisplayName ?? "Unknown" }
        return grouped.sorted { $0.key < $1.key }.map { (name: $0.key, nags: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $viewModel.filter) {
                ForEach(NagFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
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
                        Text(viewModel.filter == .open ? "All caught up!" : "No nagz to show.")
                    }
                } else {
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        List {
                            ForEach(nagsForMeByCounterpart, id: \.name) { group in
                                Section("From \(group.name)") {
                                    ForEach(group.nags) { nag in
                                        NavigationLink(value: nag.id) {
                                            NagRowView(nag: nag, currentUserId: currentUserId)
                                        }
                                    }
                                }
                            }

                            ForEach(nagsForOthersByCounterpart, id: \.name) { group in
                                Section("To \(group.name)") {
                                    ForEach(group.nags) { nag in
                                        NavigationLink(value: nag.id) {
                                            NagRowView(nag: nag, currentUserId: currentUserId)
                                        }
                                    }
                                }
                            }

                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
        }
        .navigationTitle("Nagz")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
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
            Task { await viewModel.loadNags() }
        }
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
        // Pass only the nags the user is currently viewing
        let visibleNags = viewModel.nags
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
