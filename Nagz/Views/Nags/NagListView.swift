import SwiftUI

struct NagListView: View {
    @State var viewModel: NagListViewModel
    let canCreateNags: Bool
    let familyId: UUID?
    let currentUserId: UUID?
    let webSocketService: WebSocketService
    @State private var showCreateNag = false
    @State private var wsTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    init(apiClient: APIClient, familyId: UUID?, canCreateNags: Bool, currentUserId: UUID? = nil, webSocketService: WebSocketService) {
        let vm = NagListViewModel(apiClient: apiClient)
        _viewModel = State(initialValue: vm)
        self.familyId = familyId
        self.canCreateNags = canCreateNags
        self.currentUserId = currentUserId
        self.webSocketService = webSocketService
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
                        Label("No Nags", systemImage: "checkmark.circle")
                    } description: {
                        Text(viewModel.filter == .open ? "All caught up!" : "No nags to show.")
                    }
                } else {
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        List {
                            ForEach(viewModel.nags) { nag in
                                NavigationLink(value: nag.id) {
                                    NagRowView(nag: nag, currentUserId: currentUserId)
                                }
                                .task {
                                    if nag.id == viewModel.nags.last?.id {
                                        await viewModel.loadMore()
                                    }
                                }
                            }
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Nags")
        .toolbar {
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
                case .memberAdded, .memberRemoved:
                    break // Not relevant for nag list
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
}
