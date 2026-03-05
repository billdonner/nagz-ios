import SwiftUI

struct CreateNagView: View {
    @State private var viewModel: CreateNagViewModel
    @State private var members: [MemberDetail] = []
    @State private var connections: [ConnectionResponse] = []
    @State private var caregiverChildren: [CaregiverConnectionChild] = []
    @State private var isLoadingRecipients = true
    @State private var recipientLoadError: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.databaseManager) private var databaseManager
    private let apiClient: APIClient
    private let familyId: UUID?
    private let currentUserId: UUID?

    private let preselectedConnectionId: UUID?

    init(apiClient: APIClient, familyId: UUID?, currentUserId: UUID? = nil, preselectedConnectionId: UUID? = nil, preselectedDate: Date? = nil) {
        self.apiClient = apiClient
        self.familyId = familyId
        self.currentUserId = currentUserId
        self.preselectedConnectionId = preselectedConnectionId
        _viewModel = State(initialValue: CreateNagViewModel(apiClient: apiClient, familyId: familyId, preselectedDate: preselectedDate))
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

                            if !caregiverChildren.isEmpty {
                                Section("Caregivers' Kids") {
                                    ForEach(caregiverChildren) { child in
                                        Text("\(child.displayName ?? "Unknown") (\(child.familyName))")
                                            .tag(child.userId as UUID?)
                                    }
                                }
                            }
                        }
                        .onChange(of: viewModel.recipientId) {
                            // Determine if this is a family, connection, or caregiver child recipient
                            if let rid = viewModel.recipientId {
                                if filteredMembers.contains(where: { $0.userId == rid }) {
                                    viewModel.contextFamilyId = familyId
                                    viewModel.contextConnectionId = nil
                                } else if let caregiverChild = caregiverChildren.first(where: { $0.userId == rid }) {
                                    viewModel.contextFamilyId = nil
                                    viewModel.contextConnectionId = caregiverChild.connectionId
                                } else if let conn = connections.first(where: {
                                    otherPartyId(for: $0) == rid
                                }) {
                                    viewModel.contextFamilyId = nil
                                    viewModel.contextConnectionId = conn.id
                                }
                                Task {
                                    await viewModel.applySmartDefaults(
                                        db: databaseManager,
                                        creatorId: currentUserId,
                                        recipientId: rid
                                    )
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

                    // Quick-time presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            quickTimeButton("1h", icon: "clock", interval: 3600)
                            quickTimeButton("3h", icon: "clock.fill", interval: 3 * 3600)
                            quickTimeButton("Tonight", icon: "moon.fill", hours: 20)
                            quickTimeButton("Tomorrow", icon: "sunrise.fill", tomorrowHour: 9)
                            quickTimeButton("Weekend", icon: "figure.walk", nextWeekend: true)
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

                if isSelfNag {
                    Section {
                        Label("This will remind **you**, not someone else.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
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
                            Text(isSelfNag ? "Remind Myself" : "Create Nag")
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

    private var isSelfNag: Bool {
        guard let rid = viewModel.recipientId, let uid = currentUserId else { return false }
        return rid == uid
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

    // MARK: - Quick Time Helpers

    private func quickTimeButton(_ label: String, icon: String, interval: TimeInterval? = nil, hours: Int? = nil, tomorrowHour: Int? = nil, nextWeekend: Bool = false) -> some View {
        Button {
            let cal = Calendar.current
            if let interval {
                viewModel.dueAt = Date().addingTimeInterval(interval)
            } else if let hours {
                let today = cal.startOfDay(for: Date())
                let target = cal.date(bySettingHour: hours, minute: 0, second: 0, of: today)!
                viewModel.dueAt = target > Date() ? target : target.addingTimeInterval(86400)
            } else if let tomorrowHour {
                let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
                viewModel.dueAt = cal.date(bySettingHour: tomorrowHour, minute: 0, second: 0, of: tomorrow)!
            } else if nextWeekend {
                let weekday = cal.component(.weekday, from: Date())
                let daysUntilSat = (7 - weekday + 7) % 7
                let sat = cal.date(byAdding: .day, value: daysUntilSat == 0 ? 7 : daysUntilSat, to: cal.startOfDay(for: Date()))!
                viewModel.dueAt = cal.date(bySettingHour: 10, minute: 0, second: 0, of: sat)!
            }
        } label: {
            Label(label, systemImage: icon)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray6), in: Capsule())
        }
        .buttonStyle(.plain)
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

            // Load children from caregiver connections
            var allCaregiverChildren: [CaregiverConnectionChild] = []
            for conn in connResponse.items where conn.caregiver {
                do {
                    let children: [CaregiverConnectionChild] = try await apiClient.request(
                        .listCaregiverChildren(connectionId: conn.id)
                    )
                    allCaregiverChildren.append(contentsOf: children)
                } catch {
                    // Non-critical — skip this connection's children
                }
            }
            caregiverChildren = allCaregiverChildren
        } catch let error as APIError {
            recipientLoadError = error.errorDescription
        } catch {
            recipientLoadError = "Failed to load recipients."
        }
        isLoadingRecipients = false

        // Pre-select recipient if a connection was specified
        if let preselectedConnectionId,
           let conn = connections.first(where: { $0.id == preselectedConnectionId }),
           let recipientId = otherPartyId(for: conn) {
            viewModel.recipientId = recipientId
            viewModel.contextFamilyId = nil
            viewModel.contextConnectionId = conn.id
        }
    }
}
