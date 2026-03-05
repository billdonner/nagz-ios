import SwiftUI

struct ConnectionListView: View {
    @State private var viewModel: ConnectionListViewModel
    @State private var showInvite = false
    @State private var connectionToRemove: ConnectionResponse?
    @State private var connectionToNag: ConnectionResponse?
    @State private var wsTask: Task<Void, Never>?
    let familyId: UUID?
    let currentUserId: UUID?
    let webSocketService: WebSocketService?
    let userName: String?

    init(apiClient: APIClient, familyId: UUID? = nil, currentUserId: UUID? = nil, webSocketService: WebSocketService? = nil, userName: String? = nil) {
        let vm = ConnectionListViewModel(apiClient: apiClient, currentUserId: currentUserId)
        _viewModel = State(initialValue: vm)
        self.familyId = familyId
        self.userName = userName
        self.currentUserId = currentUserId
        self.webSocketService = webSocketService
    }

    var body: some View {
        List {
            if !viewModel.pendingInvites.isEmpty {
                Section("Invites for You") {
                    ForEach(viewModel.pendingInvites) { invite in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("From: \(invite.otherPartyDisplayName ?? invite.otherPartyEmail ?? invite.inviteeEmail)")
                                    .font(.body)
                                Text("Sent \(invite.createdAt, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Accept") {
                                Task { await viewModel.accept(id: invite.id) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            Button("Decline") {
                                Task { await viewModel.decline(id: invite.id) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            if !viewModel.sentInvites.isEmpty {
                Section {
                    ForEach(viewModel.sentInvites) { invite in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(invite.otherPartyDisplayName ?? invite.otherPartyEmail ?? invite.inviteeEmail)
                                    .font(.body)
                                HStack(spacing: 6) {
                                    Text(invite.createdAt, style: .relative)
                                        .monospacedDigit()
                                    Text("ago")
                                    inviteAgeBadge(for: invite)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await viewModel.revoke(id: invite.id) }
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text("Invites You Sent")
                } footer: {
                    if let staleCount = staleInviteCount, staleCount > 0 {
                        Label(
                            staleCount == 1
                                ? "1 invite has been waiting a while — consider resharing or removing it."
                                : "\(staleCount) invites have been waiting a while — consider resharing or removing them.",
                            systemImage: "lightbulb.fill"
                        )
                    }
                }
            }

            Section {
                if viewModel.connections.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView {
                        Label("No Connections", systemImage: "person.2")
                    } description: {
                        Text("Invite someone by email to start nagging them.")
                    }
                } else {
                    ForEach(viewModel.connections) { connection in
                        Button {
                            connectionToNag = connection
                        } label: {
                            connectionRow(connection)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Remove", role: .destructive) {
                                connectionToRemove = connection
                            }
                        }
                    }
                }
            } header: {
                Text("Active Connections")
            } footer: {
                if !viewModel.connections.isEmpty {
                    Text("**Friends** can nag each other. **Caregivers** can nag your children but not you — ideal for tutors, coaches, or nannies.")
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("Remove Connection?", isPresented: Binding(
            get: { connectionToRemove != nil },
            set: { if !$0 { connectionToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) { connectionToRemove = nil }
            Button("Remove", role: .destructive) {
                if let conn = connectionToRemove {
                    Task { await viewModel.revoke(id: conn.id) }
                    connectionToRemove = nil
                }
            }
        } message: {
            if let conn = connectionToRemove {
                Text("This will disconnect you from \(conn.otherPartyDisplayName ?? conn.otherPartyEmail ?? conn.inviteeEmail). You'll need to re-invite them to reconnect.")
            }
        }
        .navigationTitle(userName.map { "\($0)'s People" } ?? "People")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInvite = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showInvite) {
            Task { await viewModel.loadConnections() }
        } content: {
            InviteConnectionView(viewModel: viewModel)
        }
        .sheet(item: $connectionToNag) {
            Task { await viewModel.loadConnections() }
        } content: { connection in
            CreateNagView(
                apiClient: viewModel.apiClient,
                familyId: familyId,
                currentUserId: currentUserId,
                preselectedConnectionId: connection.id
            )
        }
        .task { await viewModel.loadConnections() }
        .task { startWebSocket() }
        .onDisappear { stopWebSocket() }
        .refreshable { await viewModel.loadConnections() }
    }

    private func startWebSocket() {
        guard let familyId, let webSocketService, wsTask == nil else { return }
        wsTask = Task {
            let stream = await webSocketService.connect(familyId: familyId)
            for await event in stream {
                switch event.type {
                case .connectionInvited, .connectionAccepted:
                    await viewModel.loadConnections()
                default:
                    break
                }
            }
        }
    }

    private func stopWebSocket() {
        wsTask?.cancel()
        wsTask = nil
    }

    private func connectionRow(_ connection: ConnectionResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(connection.otherPartyDisplayName ?? connection.otherPartyEmail ?? connection.inviteeEmail)
                    .font(.body.weight(.medium))
                Spacer()
                Button {
                    Task { await viewModel.toggleType(id: connection.id, currentCaregiver: connection.caregiver) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: connection.caregiver ? "checkmark.shield.fill" : "shield")
                            .font(.caption)
                        Text(connection.caregiver ? "Caregiver" : "Friend")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(connection.caregiver ? .green : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(connection.caregiver ? Color.green.opacity(0.1) : Color.secondary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
            }

            if let stats = viewModel.connectionStats[connection.id] {
                HStack(spacing: 0) {
                    statPill(count: stats.sent, label: "Snt", icon: "arrow.up.circle.fill", color: .blue)
                    statPill(count: stats.received, label: "Rcvd", icon: "arrow.down.circle.fill", color: .orange)
                    statPill(count: stats.openCount, label: "Open", icon: "circle.fill", color: .yellow)
                    statPill(count: stats.completedCount, label: "Done", icon: "checkmark.circle.fill", color: .green)
                    if stats.overdueCount > 0 {
                        statPill(count: stats.overdueCount, label: "Late", icon: "exclamationmark.triangle.fill", color: .orange)
                    }
                }

                // Analytics: completion rate, on-time rate, reliability badge
                if stats.totalNags >= 3 {
                    HStack(spacing: 12) {
                        if let cr = stats.completionRate {
                            analyticsChip(value: "\(cr)%", caption: "Done", color: cr >= 70 ? .green : .orange)
                        }
                        if let otr = stats.onTimeRate {
                            analyticsChip(value: "\(otr)%", caption: "On Time", color: otr >= 70 ? .blue : .orange)
                        }
                        if let reliability = stats.reliabilityLabel {
                            let badgeColor: Color = switch stats.reliabilityColor {
                            case "green": .green
                            case "blue": .blue
                            case "orange": .orange
                            default: .red
                            }
                            Text(reliability)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badgeColor, in: Capsule())
                        }
                        Spacer()
                    }
                }
            }

            Text("Connected \(connection.respondedAt ?? connection.createdAt, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    /// Number of sent invites older than 5 days
    private var staleInviteCount: Int? {
        let stale = viewModel.sentInvites.filter { inviteAgeDays($0) >= 5 }
        return stale.isEmpty ? nil : stale.count
    }

    private func inviteAgeDays(_ invite: ConnectionResponse) -> Int {
        Int(Date().timeIntervalSince(invite.createdAt) / 86400)
    }

    @ViewBuilder
    private func inviteAgeBadge(for invite: ConnectionResponse) -> some View {
        let days = inviteAgeDays(invite)
        if days >= 14 {
            Text("Likely missed")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.red, in: Capsule())
        } else if days >= 5 {
            Text("Getting stale")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange, in: Capsule())
        }
    }

    private func analyticsChip(value: String, caption: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func statPill(count: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text("\(count)")
                    .fontWeight(.semibold)
            }
            .font(.caption)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
