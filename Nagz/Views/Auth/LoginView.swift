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
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
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
        }
        .navigationTitle("Nagz")
    }
}
