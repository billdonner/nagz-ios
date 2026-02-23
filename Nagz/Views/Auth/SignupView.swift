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
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 56))
                            .foregroundStyle(.purple)
                            .symbolRenderingMode(.hierarchical)
                        Text("Join the Family")
                            .font(.title2.bold())
                        Text("Create your account to get started")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                accountFields
                dobSection
                errorSection
                signupButton
                legalSection
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var accountFields: some View {
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
    }

    private var dobSection: some View {
        Section {
            DatePicker(
                "Date of Birth",
                selection: Binding(
                    get: { viewModel.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -13, to: Date())! },
                    set: { viewModel.dateOfBirth = $0 }
                ),
                in: ...Date(),
                displayedComponents: .date
            )

            if viewModel.isUnder13 {
                Label("Users under 13 require guardian consent before the account becomes active.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Age Verification")
        } footer: {
            Text("Required for COPPA compliance.")
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.errorMessage {
            Section {
                ErrorBanner(message: error)
            }
        }
    }

    private var signupButton: some View {
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
    }

    private var legalSection: some View {
        Section("Legal") {
            NavigationLink("Privacy Policy") {
                LegalDocumentView(apiClient: apiClient, documentType: .privacyPolicy)
            }
            NavigationLink("Terms of Service") {
                LegalDocumentView(apiClient: apiClient, documentType: .termsOfService)
            }
        }
    }
}
