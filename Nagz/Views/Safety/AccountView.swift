import SwiftUI

struct AccountView: View {
    let apiClient: APIClient
    let authManager: AuthManager
    let currentUserId: UUID
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("User ID") {
                    Text(currentUserId.uuidString.prefix(8) + "...")
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section {
                Button("Delete My Account", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .disabled(isDeleting)
            } footer: {
                Text("This will permanently delete your account, remove you from all families, and cancel your open nags. This cannot be undone.")
            }

            if let error = errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
            }
        }
        .navigationTitle("Account")
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete My Account", role: .destructive) {
                Task {
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
        } message: {
            Text("Are you sure? This permanently deletes your account and all associated data. This cannot be undone.")
        }
    }
}
