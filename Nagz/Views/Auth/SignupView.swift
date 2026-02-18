import SwiftUI

struct SignupView: View {
    @State private var viewModel: SignupViewModel
    let apiClient: APIClient
    @Environment(\.dismiss) private var dismiss

    init(authManager: AuthManager, apiClient: APIClient) {
        _viewModel = State(initialValue: SignupViewModel(authManager: authManager))
        self.apiClient = apiClient
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display Name", text: $viewModel.displayName)
                        .textContentType(.name)

                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    SecureField("Password (6+ characters)", text: $viewModel.password)
                        .textContentType(.newPassword)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: error)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.signup() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign Up")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                } footer: {
                    Text("By signing up, you agree to our Terms of Service and Privacy Policy.")
                }

                Section("Legal") {
                    NavigationLink("Privacy Policy") {
                        LegalDocumentView(apiClient: apiClient, documentType: .privacyPolicy)
                    }
                    NavigationLink("Terms of Service") {
                        LegalDocumentView(apiClient: apiClient, documentType: .termsOfService)
                    }
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
