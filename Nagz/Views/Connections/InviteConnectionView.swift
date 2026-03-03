import SwiftUI

struct InviteConnectionView: View {
    @Bindable var viewModel: ConnectionListViewModel
    @State private var showShareSheet = false
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

                Section {
                    Text("This registers the invite on Nagz. You'll share the details with them next.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        Task {
                            await viewModel.sendInvite()
                            if viewModel.inviteSuccess {
                                showShareSheet = true
                            }
                        }
                    } label: {
                        if viewModel.isInviting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Create Invite & Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.inviteEmail.isEmpty || viewModel.isInviting)
                }
            }
            .navigationTitle("Invite Someone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: {
                // Whether they shared or cancelled, dismiss back to People list
                viewModel.inviteSuccess = false
                viewModel.invitedEmail = ""
                dismiss()
            }) {
                ActivitySheet(items: [shareMessage])
            }
        }
    }

    private var shareMessage: String {
        let email = viewModel.invitedEmail
        if email.isEmpty {
            return "I'm using Nagz to stay on top of family reminders! Download it and connect with me: https://nagz.online"
        }
        return "I invited you to Nagz! Download the app and sign up with \(email) so we can stay connected. https://nagz.online"
    }
}

/// Wraps UIActivityViewController for programmatic share sheet presentation.
private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
