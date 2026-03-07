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
                            .accessibilityLabel("Cancel invite")
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
                if viewModel.connections.isEmpty && !viewModel.loadState.isLoading {
                    ContentUnavailableView {
                        Label("No Connections", systemImage: "person.2")
                    } description: {
                        Text("Invite someone by email to start nagging them.")
                    }
                } else {
                    ForEach(viewModel.connections) { connection in
                        connectionRow(connection)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    connectionToNag = connection
                                } label: {
                                    Label("Nag", systemImage: "bell.fill")
                                }
                                .tint(.blue)
                            }
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
        .navigationDestination(for: ConnectionNagFilter.self) { filter in
            ConnectionNagListView(apiClient: viewModel.apiClient, filter: filter, currentUserId: currentUserId)
        }
        .navigationTitle(userName.map { "\($0)'s People" } ?? "People")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInvite = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Invite someone")
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
                .accessibilityLabel(connection.caregiver ? "Switch to Friend" : "Switch to Caregiver")

                Button {
                    connectionToNag = connection
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Nag \(connection.otherPartyDisplayName ?? connection.otherPartyEmail ?? "person")")
            }

            if let stats = viewModel.connectionStats[connection.id] {
                let name = connection.otherPartyDisplayName ?? connection.otherPartyEmail ?? connection.inviteeEmail
                HStack(spacing: 0) {
                    statPill(count: stats.sent, label: "Snt", icon: "arrow.up.circle.fill", color: .blue,
                             destination: .init(connectionId: connection.id, personName: name, filterType: .sent))
                    statPill(count: stats.received, label: "Rcvd", icon: "arrow.down.circle.fill", color: .orange,
                             destination: .init(connectionId: connection.id, personName: name, filterType: .received))
                    statPill(count: stats.openCount, label: "Open", icon: "circle.fill", color: .yellow,
                             destination: .init(connectionId: connection.id, personName: name, filterType: .open))
                    statPill(count: stats.completedCount, label: "Done", icon: "checkmark.circle.fill", color: .green,
                             destination: .init(connectionId: connection.id, personName: name, filterType: .done))
                    if stats.overdueCount > 0 {
                        statPill(count: stats.overdueCount, label: "Late", icon: "exclamationmark.triangle.fill", color: .orange,
                                 destination: .init(connectionId: connection.id, personName: name, filterType: .late))
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

    private func statPill(count: Int, label: String, icon: String, color: Color, destination: ConnectionNagFilter) -> some View {
        NavigationLink(value: destination) {
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: icon)
                        .foregroundStyle(count > 0 ? color : Color.secondary)
                    Text("\(count)")
                        .fontWeight(.semibold)
                        .foregroundStyle(count > 0 ? Color.primary : Color.secondary)
                }
                .font(.caption)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
    }
}

// MARK: - Navigation value

struct ConnectionNagFilter: Hashable {
    let connectionId: UUID
    let personName: String
    let filterType: FilterType

    enum FilterType: String, Hashable {
        case sent = "Sent"
        case received = "Received"
        case open = "Open"
        case done = "Done"
        case late = "Late"
    }
}

// MARK: - Filtered nag list

struct ConnectionNagListView: View {
    let apiClient: APIClient
    let filter: ConnectionNagFilter
    let currentUserId: UUID?

    @State private var loadState: LoadState<[NagResponse]> = .idle

    private var nags: [NagResponse] { loadState.value ?? [] }

    var body: some View {
        Group {
            if loadState.isLoading && nags.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if nags.isEmpty {
                ContentUnavailableView {
                    Label("No Nagz", systemImage: "checkmark.circle")
                } description: {
                    Text("No \(filter.filterType.rawValue.lowercased()) nags with \(filter.personName).")
                }
            } else {
                List(nags) { nag in
                    NavigationLink(value: nag.id) {
                        NagRowView(nag: nag, currentUserId: currentUserId)
                    }
                }
            }
        }
        .navigationDestination(for: UUID.self) { nagId in
            NagDetailView(apiClient: apiClient, nagId: nagId, currentUserId: currentUserId ?? UUID())
        }
        .navigationTitle("\(filter.personName) · \(filter.filterType.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        if loadState.value == nil { loadState = .loading }
        do {
            let status: NagStatus? = switch filter.filterType {
            case .done: .completed
            case .sent, .received, .open, .late: .open
            }
            let page: PaginatedResponse<NagResponse> = try await apiClient.request(
                .listNags(connectionId: filter.connectionId, status: status)
            )
            let now = Date()
            loadState = .success(page.items.filter { nag in
                switch filter.filterType {
                case .sent:     return nag.creatorId == currentUserId
                case .received: return nag.recipientId == currentUserId && nag.creatorId != currentUserId
                case .open:     return true
                case .done:     return true
                case .late:     return nag.dueAt < now
                }
            })
        } catch {
            if loadState.value == nil { loadState = .failure(error) }
        }
    }
}
