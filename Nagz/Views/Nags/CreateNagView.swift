import SwiftUI

struct CreateNagView: View {
    @State private var viewModel: CreateNagViewModel
    @State private var members: [MemberDetail] = []
    @State private var connections: [ConnectionResponse] = []
    @State private var trustedChildren: [TrustedConnectionChild] = []
    @State private var isLoadingRecipients = true
    @State private var recipientLoadError: String?
    @Environment(\.dismiss) private var dismiss
    private let apiClient: APIClient
    private let familyId: UUID?
    private let currentUserId: UUID?

    init(apiClient: APIClient, familyId: UUID?, currentUserId: UUID? = nil) {
        self.apiClient = apiClient
        self.familyId = familyId
        self.currentUserId = currentUserId
        _viewModel = State(initialValue: CreateNagViewModel(apiClient: apiClient, familyId: familyId))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipient") {
                    if isLoadingRecipients {
                        ProgressView("Loading recipients...")
                    } else if let error = recipientLoadError {
                        ErrorBanner(message: error) {
                            await loadRecipients()
                        }
                    } else {
                        Picker("Send to", selection: $viewModel.recipientId) {
                            Text("Select...").tag(nil as UUID?)

                            if !filteredMembers.isEmpty {
                                Section("Family Members") {
                                    ForEach(filteredMembers) { member in
                                        Text(member.displayName ?? "Unknown")
                                            .tag(member.userId as UUID?)
                                    }
                                }
                            }

                            if !connections.isEmpty {
                                Section("Connections") {
                                    ForEach(connections) { conn in
                                        Text(conn.otherPartyDisplayName ?? conn.otherPartyEmail ?? conn.inviteeEmail)
                                            .tag(otherPartyId(for: conn) as UUID?)
                                    }
                                }
                            }

                            if !trustedChildren.isEmpty {
                                Section("Trusted Connections' Kids") {
                                    ForEach(trustedChildren) { child in
                                        Text("\(child.displayName ?? "Unknown") (\(child.familyName))")
                                            .tag(child.userId as UUID?)
                                    }
                                }
                            }
                        }
                        .onChange(of: viewModel.recipientId) {
                            // Determine if this is a family, connection, or trusted child recipient
                            if let rid = viewModel.recipientId {
                                if filteredMembers.contains(where: { $0.userId == rid }) {
                                    viewModel.contextFamilyId = familyId
                                    viewModel.contextConnectionId = nil
                                } else if let trustedChild = trustedChildren.first(where: { $0.userId == rid }) {
                                    viewModel.contextFamilyId = nil
                                    viewModel.contextConnectionId = trustedChild.connectionId
                                } else if let conn = connections.first(where: {
                                    otherPartyId(for: $0) == rid
                                }) {
                                    viewModel.contextFamilyId = nil
                                    viewModel.contextConnectionId = conn.id
                                }
                            }
                        }
                    }
                }

                Section("Details") {
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(NagCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.iconName)
                                .tag(cat)
                        }
                    }

                    DatePicker("Due", selection: $viewModel.dueAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])

                    Picker("Completion Type", selection: $viewModel.doneDefinition) {
                        ForEach(DoneDefinition.allCases, id: \.self) { def in
                            Text(def.displayName).tag(def)
                        }
                    }
                }

                Section("Repeat") {
                    Picker("Recurrence", selection: $viewModel.recurrence) {
                        Text("None").tag(nil as Recurrence?)
                        ForEach(Recurrence.allCases, id: \.self) { r in
                            Text(r.displayName).tag(r as Recurrence?)
                        }
                    }
                    .onChange(of: viewModel.recurrence) {
                        if let r = viewModel.recurrence {
                            viewModel.dueAt = Date().addingTimeInterval(r.timeInterval)
                        }
                    }
                }

                Section("Description (Optional)") {
                    TextField("What needs to be done?", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: error)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.createNag() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Nag")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                }
            }
            .navigationTitle("New Nag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadRecipients() }
            .onChange(of: viewModel.didCreate) {
                if viewModel.didCreate { dismiss() }
            }
        }
    }

    private var filteredMembers: [MemberDetail] {
        members.filter { $0.userId != currentUserId }
    }

    private func otherPartyId(for conn: ConnectionResponse) -> UUID? {
        if conn.inviterId == currentUserId {
            return conn.inviteeId
        } else {
            return conn.inviterId
        }
    }

    private func loadRecipients() async {
        isLoadingRecipients = true
        recipientLoadError = nil
        do {
            // Load family members if we have a family
            if let familyId {
                let memberResponse: PaginatedResponse<MemberDetail> = try await apiClient.request(
                    .listMembers(familyId: familyId)
                )
                members = memberResponse.items
            }

            // Always load active connections
            let connResponse: PaginatedResponse<ConnectionResponse> = try await apiClient.request(
                .listConnections(status: .active)
            )
            connections = connResponse.items

            // Load trusted children from trusted connections
            var allTrustedChildren: [TrustedConnectionChild] = []
            for conn in connResponse.items where conn.trusted {
                do {
                    let children: [TrustedConnectionChild] = try await apiClient.request(
                        .listTrustedChildren(connectionId: conn.id)
                    )
                    allTrustedChildren.append(contentsOf: children)
                } catch {
                    // Non-critical — skip this connection's children
                }
            }
            trustedChildren = allTrustedChildren
        } catch let error as APIError {
            recipientLoadError = error.errorDescription
        } catch {
            recipientLoadError = "Failed to load recipients."
        }
        isLoadingRecipients = false
    }
}
