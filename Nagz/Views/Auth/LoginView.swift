import SwiftUI

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    @Binding var showSignup: Bool

    init(authManager: AuthManager, showSignup: Binding<Bool>) {
        _viewModel = State(initialValue: LoginViewModel(authManager: authManager))
        _showSignup = showSignup
    }

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
            }

            if let error = viewModel.errorMessage {
                Section {
                    ErrorBanner(message: error)
                }
            }

            Section {
                Button {
                    Task { await viewModel.login() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Log In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!viewModel.isValid || viewModel.isLoading)

                Button("Create Account") {
                    showSignup = true
                }
            }
            Section {
                Text("Nagz uses accounts so your family members can share reminders, track tasks, and receive notifications across devices. Your data stays private and you can delete your account at any time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Nagz")
    }
}
