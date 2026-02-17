import SwiftUI

struct JoinFamilyView: View {
    @Bindable var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite Code") {
                    TextField("Paste invite code from guardian", text: $viewModel.joinInviteCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.joinFamily() }
                    } label: {
                        if viewModel.isJoining {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Join Family")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.joinInviteCode.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isJoining)
                }
            }
            .navigationTitle("Join Family")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
