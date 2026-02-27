import SwiftUI

/// Simplified nag list for children — large colorful cards, swipe to complete.
struct ChildNagListView: View {
    let apiClient: APIClient
    let familyId: UUID?
    let currentUserId: UUID?
    let webSocketService: WebSocketService

    @State private var nags: [NagResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var wsTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading your nags...")
            } else if nags.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("All done!")
                        .font(.title2.bold())
                    Text("No nags right now. Great job!")
                        .foregroundStyle(.secondary)
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
    }

    private func loadNags() async {
        guard let familyId else { return }
        isLoading = nags.isEmpty
        do {
            let response: PaginatedResponse<NagResponse> = try await apiClient.request(
                .listNags(familyId: familyId, status: .open)
            )
            // Only show nags where the child is the recipient
            nags = response.items.filter { $0.recipientId == currentUserId }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func completeNag(_ nag: NagResponse) async {
        do {
            let _: NagResponse = try await apiClient.request(
                .updateNagStatus(nagId: nag.id, status: .completed)
            )
            nags.removeAll { $0.id == nag.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startWebSocket() {
        guard let familyId, wsTask == nil else { return }
        wsTask = Task {
            let stream = await webSocketService.connect(familyId: familyId)
            for await event in stream {
                switch event.type {
                case .nagCreated, .nagUpdated, .nagStatusChanged:
                    await loadNags()
                case .excuseSubmitted, .memberAdded, .memberRemoved, .ping, .pong:
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
