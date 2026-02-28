import SwiftUI

struct ConnectionListView: View {
    @State private var viewModel: ConnectionListViewModel
    @State private var showInvite = false
    @State private var connectionToRemove: ConnectionResponse?
    @State private var connectionToNag: ConnectionResponse?
    let familyId: UUID?
    let currentUserId: UUID?

    init(apiClient: APIClient, familyId: UUID? = nil, currentUserId: UUID? = nil) {
        _viewModel = State(initialValue: ConnectionListViewModel(apiClient: apiClient))
        self.familyId = familyId
        self.currentUserId = currentUserId
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
                Section("Invites You Sent") {
                    ForEach(viewModel.sentInvites) { invite in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(invite.otherPartyDisplayName ?? invite.otherPartyEmail ?? invite.inviteeEmail)
                                    .font(.body)
                                Text("Waiting for response \u{2022} \(invite.createdAt, style: .relative) ago")
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
                }
            }

            Section("Active Connections") {
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
        .navigationTitle("People")
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
        .sheet(item: $connectionToNag) { connection in
            CreateNagView(
                apiClient: viewModel.apiClient,
                familyId: familyId,
                currentUserId: currentUserId,
                preselectedConnectionId: connection.id
            )
        }
        .task { await viewModel.loadConnections() }
        .refreshable { await viewModel.loadConnections() }
    }

    private func connectionRow(_ connection: ConnectionResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(connection.otherPartyDisplayName ?? connection.otherPartyEmail ?? connection.inviteeEmail)
                    .font(.body.weight(.medium))
                Spacer()
                if connection.trusted {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                Toggle("Trusted", isOn: Binding(
                    get: { connection.trusted },
                    set: { _ in
                        Task { await viewModel.toggleTrust(id: connection.id, currentTrusted: connection.trusted) }
                    }
                ))
                .labelsHidden()
                .buttonStyle(.borderless)
            }

            if let stats = viewModel.connectionStats[connection.id] {
                HStack(spacing: 16) {
                    statLabel(count: stats.sent, label: "Sent", icon: "arrow.up.circle.fill", color: .blue)
                    statLabel(count: stats.received, label: "Received", icon: "arrow.down.circle.fill", color: .orange)
                    statLabel(count: stats.openCount, label: "Open", icon: "circle.fill", color: .yellow)
                    statLabel(count: stats.completedCount, label: "Done", icon: "checkmark.circle.fill", color: .green)
                }
                .font(.caption)
            }

            Text("Connected \(connection.respondedAt ?? connection.createdAt, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func statLabel(count: Int, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(count)")
                .fontWeight(.semibold)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}
