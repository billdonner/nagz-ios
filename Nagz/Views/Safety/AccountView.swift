import SwiftUI

struct AccountView: View {
    let apiClient: APIClient
    let authManager: AuthManager
    let currentUserId: UUID
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isExporting = false
    @State private var showExportSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            accountSection
            legalSection
            exportSection
            deleteSection
            errorSection
        }
        .navigationTitle("Account")
        .alert("Export Complete", isPresented: $showExportSuccess) {
            Button("OK") {}
        } message: {
            Text("Your data export has been prepared. You will receive it shortly.")
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete My Account", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Are you sure? This permanently deletes your account and all associated data. This cannot be undone.")
        }
    }

    private var accountSection: some View {
        Section("Account") {
            LabeledContent("User ID") {
                Text(currentUserId.uuidString.prefix(8) + "...")
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private var legalSection: some View {
        Section("Legal") {
            NavigationLink {
                LegalDocumentView(apiClient: apiClient, documentType: .privacyPolicy)
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }
            NavigationLink {
                LegalDocumentView(apiClient: apiClient, documentType: .termsOfService)
            } label: {
                Label("Terms of Service", systemImage: "doc.text.fill")
            }
        }
    }

    private var exportSection: some View {
        Section {
            Button {
                Task { await exportData() }
            } label: {
                HStack {
                    Label("Export My Data", systemImage: "square.and.arrow.up")
                    Spacer()
                    if isExporting {
                        ProgressView()
                    }
                }
            }
            .disabled(isExporting)
        } header: {
            Text("Your Data")
        } footer: {
            Text("Download a copy of all your personal data (GDPR/CCPA).")
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete My Account", role: .destructive) {
                showDeleteConfirmation = true
            }
            .disabled(isDeleting)
        } footer: {
            Text("This will permanently delete your account, remove you from all families, and cancel your open nags. This cannot be undone.")
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = errorMessage {
            Section {
                Text(error).foregroundStyle(.red).font(.callout)
            }
        }
    }

    private func exportData() async {
        isExporting = true
        errorMessage = nil
        do {
            let _: [String: AnyCodableValue] = try await apiClient.request(.exportAccountData())
            showExportSuccess = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isExporting = false
    }

    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil
        do {
            let _: AccountResponse = try await apiClient.request(
                .deleteAccount(userId: currentUserId)
            )
            await authManager.logout()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}
