import SwiftUI

struct CreateNagView: View {
    @State private var viewModel: CreateNagViewModel
    @State private var members: [MemberDetail] = []
    @State private var isLoadingMembers = true
    @State private var memberLoadError: String?
    @Environment(\.dismiss) private var dismiss
    private let apiClient: APIClient
    private let familyId: UUID

    init(apiClient: APIClient, familyId: UUID) {
        self.apiClient = apiClient
        self.familyId = familyId
        _viewModel = State(initialValue: CreateNagViewModel(apiClient: apiClient, familyId: familyId))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipient") {
                    if isLoadingMembers {
                        ProgressView("Loading members...")
                    } else if let memberError = memberLoadError {
                        ErrorBanner(message: memberError) {
                            await loadMembers()
                        }
                    } else {
                        Picker("Send to", selection: $viewModel.recipientId) {
                            Text("Select...").tag(nil as UUID?)
                            ForEach(members) { member in
                                Text(member.displayName ?? "Unknown")
                                    .tag(member.userId as UUID?)
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
            .task { await loadMembers() }
            .onChange(of: viewModel.didCreate) {
                if viewModel.didCreate { dismiss() }
            }
        }
    }

    private func loadMembers() async {
        isLoadingMembers = true
        memberLoadError = nil
        do {
            let response: PaginatedResponse<MemberDetail> = try await apiClient.request(
                .listMembers(familyId: familyId)
            )
            members = response.items
        } catch let error as APIError {
            memberLoadError = error.errorDescription
        } catch {
            memberLoadError = "Failed to load family members."
        }
        isLoadingMembers = false
    }
}
