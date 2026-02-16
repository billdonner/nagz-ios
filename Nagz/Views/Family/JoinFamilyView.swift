import SwiftUI

struct JoinFamilyView: View {
    @Bindable var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Family Details") {
                    TextField("Family ID", text: $viewModel.joinFamilyId)
                        .textInputAutocapitalization(.never)

                    TextField("Invite Code", text: $viewModel.joinInviteCode)
                        .textInputAutocapitalization(.never)
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
                    .disabled(viewModel.joinFamilyId.isEmpty || viewModel.joinInviteCode.isEmpty || viewModel.isJoining)
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
