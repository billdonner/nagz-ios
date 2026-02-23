import SwiftUI

struct InviteConnectionView: View {
    @Bindable var viewModel: ConnectionListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite by Email") {
                    TextField("Email address", text: $viewModel.inviteEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let error = viewModel.inviteError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.sendInvite() }
                    } label: {
                        if viewModel.isInviting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Send Invite")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.inviteEmail.isEmpty || viewModel.isInviting)
                }
            }
            .navigationTitle("Invite Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: viewModel.inviteSuccess) {
                if viewModel.inviteSuccess { dismiss() }
            }
        }
    }
}
