import SwiftUI
import NagzAI

/// Simplified nag list for children — large colorful cards, swipe to complete.
struct ChildNagListView: View {
    let apiClient: APIClient
    let familyId: UUID?
    let currentUserId: UUID?
    let webSocketService: WebSocketService

    @State private var loadState: LoadState<[NagResponse]> = .idle
    @State private var wsTask: Task<Void, Never>?
    @State private var aiSummary: String?
    @State private var showAISummary = false

    private var nags: [NagResponse] { loadState.value ?? [] }

    var body: some View {
        Group {
            if loadState.isIdle || (loadState.isLoading && nags.isEmpty) {
                ProgressView("Loading your nags...")
            } else if nags.isEmpty {
                ContentUnavailableView {
                    Label("All Done!", systemImage: "checkmark.circle.fill")
                } description: {
                    Text("No nags right now. Great job!")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(nags, id: \.id) { nag in
                            ChildNagRowView(nag: nag) {
                                await completeNag(nag)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .refreshable { await loadNags() }
        .task { await loadNags() }
        .onAppear { startWebSocket() }
        .onDisappear { stopWebSocket() }
        .toolbar {
            if NagzAI.Router.isAppleIntelligenceAvailable {
                ToolbarItem(placement: .automatic) {
                    Button { Task { await generateSummary() } } label: {
                        Image(systemName: "sparkles")
                    }
                    .disabled(nags.isEmpty)
                    .accessibilityLabel("AI Summary")
                }
            }
        }
        .alert("How You're Doing", isPresented: $showAISummary) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(aiSummary ?? "")
        }
    }

    private func loadNags() async {
        guard let familyId else { return }
        if loadState.value == nil { loadState = .loading }
        do {
            let response: PaginatedResponse<NagResponse> = try await apiClient.request(
                .listNags(familyId: familyId, status: .open)
            )
            // Only show nags where the child is the recipient
            loadState = .success(response.items.filter { $0.recipientId == currentUserId })
        } catch {
            if loadState.value == nil { loadState = .failure(error) }
        }
    }

    private func completeNag(_ nag: NagResponse) async {
        do {
            let _: NagResponse = try await apiClient.request(
                .updateNagStatus(nagId: nag.id, status: .completed)
            )
            if case .success(var current) = loadState {
                current.removeAll { $0.id == nag.id }
                loadState = .success(current)
            }
        } catch {
            // error swallowed — row stays visible until next refresh
        }
    }

    private func startWebSocket() {
        guard let familyId, wsTask == nil else { return }
        wsTask = Task {
            let stream = await webSocketService.connect(familyId: familyId)
            for await event in stream {
                switch event.type {
                case .nagCreated, .nagUpdated, .nagStatusChanged, .nagWithdrawn:
                    await loadNags()
                case .excuseSubmitted, .memberAdded, .memberRemoved, .connectionInvited, .connectionAccepted, .ping, .pong:
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
        let items = nags.map { nag in
            NagSummaryItem(
                category: nag.category.rawValue,
                status: nag.status.rawValue,
                dueAt: nag.dueAt,
                description: nag.description
            )
        }
        let context = ListSummaryContext(nags: items, filterStatus: "open", isChild: true)
        do {
            let result = try await NagzAI.Router().listSummary(context: context)
            aiSummary = result.summary
            showAISummary = true
        } catch {
            aiSummary = "Couldn't figure out your summary."
            showAISummary = true
        }
    }
}
