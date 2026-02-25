import SwiftUI

struct InviteConnectionView: View {
    @Bindable var viewModel: ConnectionListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if viewModel.inviteSuccess {
                inviteSuccessView
            } else {
                inviteFormView
            }
        }
    }

    private var inviteFormView: some View {
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
                    Label {
                        Text(error)
                    } icon: {
                        Image(systemName: "person.fill.questionmark")
                            .foregroundStyle(.orange)
                    }
                    .foregroundStyle(.secondary)
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
    }

    private var inviteSuccessView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Invite Sent!")
                .font(.title2.bold())

            Text("Let them know to download Nagz and sign up.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ShareLink(item: shareMessage) {
                Label("Share with \(viewModel.invitedEmail)", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Button("Done") {
                viewModel.inviteSuccess = false
                viewModel.invitedEmail = ""
                dismiss()
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .navigationTitle("Invite Sent")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    viewModel.inviteSuccess = false
                    viewModel.invitedEmail = ""
                    dismiss()
                }
            }
        }
    }

    private var shareMessage: String {
        if viewModel.invitedEmail.isEmpty {
            return "I'm using Nagz to stay on top of family reminders! Download it and connect with me: https://nagz.online"
        }
        return "I invited you to Nagz! Download the app and sign up with \(viewModel.invitedEmail) so we can stay connected. https://nagz.online"
    }
}
