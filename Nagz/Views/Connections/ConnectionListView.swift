import SwiftUI

struct ConnectionListView: View {
    @State private var viewModel: ConnectionListViewModel
    @State private var showInvite = false

    init(apiClient: APIClient) {
        _viewModel = State(initialValue: ConnectionListViewModel(apiClient: apiClient))
    }

    var body: some View {
        List {
            if !viewModel.pendingInvites.isEmpty {
                Section("Invites for You") {
                    ForEach(viewModel.pendingInvites) { invite in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("From: \(invite.inviteeEmail)")
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

            Section("Active Connections") {
                if viewModel.connections.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView {
                        Label("No Connections", systemImage: "person.2")
                    } description: {
                        Text("Invite someone by email to start nagging them.")
                    }
                } else {
                    ForEach(viewModel.connections) { connection in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(connection.inviteeEmail)
                                    .font(.body)
                                Text("Connected \(connection.respondedAt ?? connection.createdAt, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await viewModel.revoke(id: connection.id) }
                            } label: {
                                Image(systemName: "xmark.circle")
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
        .task { await viewModel.loadConnections() }
        .refreshable { await viewModel.loadConnections() }
    }
}
