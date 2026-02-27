import SwiftUI

struct ManageMembersView: View {
    @State private var viewModel: ManageMembersViewModel
    @State private var credentialsMember: MemberDetail?
    @State private var credUsername = ""
    @State private var credPin = ""
    @State private var credError: String?
    @State private var isSavingCreds = false

    private let apiClient: APIClient
    private let familyId: UUID

    init(apiClient: APIClient, familyId: UUID) {
        self.apiClient = apiClient
        self.familyId = familyId
        _viewModel = State(initialValue: ManageMembersViewModel(apiClient: apiClient, familyId: familyId))
    }

    var body: some View {
        List {
            ForEach(viewModel.members) { member in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.displayName ?? "Unknown")
                            .font(.body)
                        HStack(spacing: 8) {
                            Text(member.role.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if member.role == .child {
                                if member.hasChildLogin == true {
                                    Label("Login Set", systemImage: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                } else {
                                    Label("No Login", systemImage: "exclamationmark.circle")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    Spacer()

                    if member.role == .child {
                        Menu {
                            Button {
                                credentialsMember = member
                                credUsername = ""
                                credPin = ""
                                credError = nil
                            } label: {
                                Label(member.hasChildLogin == true ? "Update Login" : "Set Login", systemImage: "key.fill")
                            }

                            NavigationLink {
                                ChildControlsView(
                                    apiClient: apiClient,
                                    familyId: familyId,
                                    childUserId: member.userId,
                                    childName: member.displayName ?? "Child"
                                )
                            } label: {
                                Label("Controls", systemImage: "slider.horizontal.3")
                            }

                            Button(role: .destructive) {
                                viewModel.memberToRemove = member
                                viewModel.showRemoveConfirmation = true
                            } label: {
                                Label("Remove", systemImage: "person.badge.minus")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    } else if member.role != .guardian {
                        Button(role: .destructive) {
                            viewModel.memberToRemove = member
                            viewModel.showRemoveConfirmation = true
                        } label: {
                            Image(systemName: "person.badge.minus")
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }
        }
        .navigationTitle("Manage Members")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateMemberSheet(viewModel: viewModel)
        }
        .sheet(item: $credentialsMember) { member in
            SetCredentialsSheet(
                member: member,
                username: $credUsername,
                pin: $credPin,
                error: $credError,
                isSaving: $isSavingCreds
            ) {
                await saveCredentials(for: member)
            }
        }
        .confirmationDialog(
            "Remove Member",
            isPresented: $viewModel.showRemoveConfirmation,
            presenting: viewModel.memberToRemove
        ) { member in
            Button("Remove \(member.displayName ?? "member")", role: .destructive) {
                Task { await viewModel.removeMember(member) }
            }
        } message: { member in
            Text("Remove \(member.displayName ?? "this member") from the family? Their open nags will be cancelled.")
        }
    }

    private func saveCredentials(for member: MemberDetail) async {
        guard credUsername.count >= 1, credPin.count == 4, credPin.allSatisfy(\.isNumber) else {
            credError = "Username required and PIN must be 4 digits"
            return
        }
        isSavingCreds = true
        credError = nil
        do {
            let _: MemberDetail = try await apiClient.request(
                .setChildCredentials(familyId: familyId, userId: member.userId, username: credUsername, pin: credPin)
            )
            credentialsMember = nil
            await viewModel.load()
        } catch let error as APIError {
            credError = error.errorDescription
        } catch {
            credError = error.localizedDescription
        }
        isSavingCreds = false
    }
}

private struct SetCredentialsSheet: View {
    let member: MemberDetail
    @Binding var username: String
    @Binding var pin: String
    @Binding var error: String?
    @Binding var isSaving: Bool
    let onSave: () async -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Child Login for \(member.displayName ?? "Child")") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("4-Digit PIN", text: $pin)
                        .keyboardType(.numberPad)
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Set Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await onSave() }
                    }
                    .disabled(username.isEmpty || pin.count != 4 || isSaving)
                }
            }
        }
    }
}

private struct CreateMemberSheet: View {
    @Bindable var viewModel: ManageMembersViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("New Member") {
                    TextField("Display Name", text: $viewModel.newMemberName)
                    Picker("Role", selection: $viewModel.newMemberRole) {
                        Text("Child").tag(FamilyRole.child)
                        Text("Participant").tag(FamilyRole.participant)
                        Text("Guardian").tag(FamilyRole.guardian)
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: error)
                    }
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await viewModel.createMember() }
                    }
                    .disabled(viewModel.newMemberName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isCreating)
                }
            }
        }
    }
}
