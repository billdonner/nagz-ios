import SwiftUI

/// Minimal settings for child users — change PIN, display name, logout.
struct ChildSettingsView: View {
    let authManager: AuthManager
    let apiClient: APIClient
    let familyId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var showPinChange = false
    @State private var currentPin = ""
    @State private var newPin = ""
    @State private var confirmPin = ""
    @State private var pinError: String?
    @State private var pinSuccess = false
    @State private var isChangingPin = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let user = authManager.currentUser {
                        LabeledContent("Name", value: user.displayName ?? "—")
                    }
                }

                Section("PIN") {
                    Button("Change PIN") {
                        showPinChange = true
                        currentPin = ""
                        newPin = ""
                        confirmPin = ""
                        pinError = nil
                        pinSuccess = false
                    }
                }

                Section {
                    Button("Log Out", role: .destructive) {
                        Task {
                            await authManager.logout()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPinChange) {
                pinChangeSheet
            }
        }
    }

    private var pinChangeSheet: some View {
        NavigationStack {
            Form {
                Section("Current PIN") {
                    SecureField("Current PIN", text: $currentPin)
                        .keyboardType(.numberPad)
                }

                Section("New PIN") {
                    SecureField("New PIN (4 digits)", text: $newPin)
                        .keyboardType(.numberPad)
                    SecureField("Confirm New PIN", text: $confirmPin)
                        .keyboardType(.numberPad)
                }

                if let error = pinError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                if pinSuccess {
                    Section {
                        Label("PIN changed successfully!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Change PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPinChange = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await changePIN() }
                    }
                    .disabled(isChangingPin || currentPin.count != 4 || newPin.count != 4 || newPin != confirmPin)
                }
            }
        }
    }

    private func changePIN() async {
        guard let familyId, let userId = authManager.currentUser?.id else { return }
        guard newPin == confirmPin else {
            pinError = "New PINs don't match"
            return
        }
        guard newPin.count == 4, newPin.allSatisfy(\.isNumber) else {
            pinError = "PIN must be exactly 4 digits"
            return
        }

        isChangingPin = true
        pinError = nil
        do {
            let _: [String: String] = try await apiClient.request(
                .changePin(familyId: familyId, userId: userId, currentPin: currentPin, newPin: newPin)
            )
            pinSuccess = true
        } catch let error as APIError {
            pinError = error.errorDescription
        } catch {
            pinError = error.localizedDescription
        }
        isChangingPin = false
    }
}
