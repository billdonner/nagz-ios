import SwiftUI

struct ManageMembersView: View {
    @State private var viewModel: ManageMembersViewModel

    init(apiClient: APIClient, familyId: UUID) {
        _viewModel = State(initialValue: ManageMembersViewModel(apiClient: apiClient, familyId: familyId))
    }

    var body: some View {
        List {
            ForEach(viewModel.members) { member in
                HStack {
                    VStack(alignment: .leading) {
                        Text(member.displayName ?? "Unknown")
                            .font(.body)
                        Text(member.role.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if member.role == .child {
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
                Text(error).foregroundStyle(.red).font(.callout)
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
                        Text("Guardian").tag(FamilyRole.guardian)
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.callout)
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
