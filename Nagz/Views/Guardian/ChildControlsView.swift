import SwiftUI

/// Guardian UI for managing per-child controls (snooze, excuses, quiet hours).
struct ChildControlsView: View {
    let apiClient: APIClient
    let familyId: UUID
    let childUserId: UUID
    let childName: String

    @State private var settings: ChildSettingsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSaving = false

    // Editable fields
    @State private var canSnooze = true
    @State private var maxSnoozes = 3
    @State private var canSubmitExcuses = true
    @State private var quietHoursEnabled = false
    @State private var quietStart = DateComponents(hour: 21, minute: 0)
    @State private var quietEnd = DateComponents(hour: 7, minute: 0)

    var body: some View {
        Form {
            if isLoading {
                ProgressView()
            } else {
                Section("Snooze Controls") {
                    Toggle("Can Snooze Nags", isOn: $canSnooze)
                    if canSnooze {
                        Stepper("Max Snoozes/Day: \(maxSnoozes)", value: $maxSnoozes, in: 0...99)
                    }
                }

                Section("Excuses") {
                    Toggle("Can Submit Excuses", isOn: $canSubmitExcuses)
                }

                Section("Quiet Hours") {
                    Toggle("Enable Quiet Hours", isOn: $quietHoursEnabled)
                    if quietHoursEnabled {
                        DatePicker("Start", selection: quietStartBinding, displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: quietEndBinding, displayedComponents: .hourAndMinute)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await saveSettings() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .navigationTitle("\(childName) Controls")
        .task { await loadSettings() }
    }

    private var quietStartBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: quietStart) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                quietStart = comps
            }
        )
    }

    private var quietEndBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: quietEnd) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                quietEnd = comps
            }
        )
    }

    private func loadSettings() async {
        do {
            let response: ChildSettingsResponse = try await apiClient.request(
                .getChildSettings(familyId: familyId, userId: childUserId)
            )
            settings = response
            canSnooze = response.canSnooze
            maxSnoozes = response.maxSnoozesPerDay
            canSubmitExcuses = response.canSubmitExcuses
            quietHoursEnabled = response.quietHoursStart != nil
            if let start = response.quietHoursStart {
                let parts = start.split(separator: ":")
                if parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                    quietStart = DateComponents(hour: h, minute: m)
                }
            }
            if let end = response.quietHoursEnd {
                let parts = end.split(separator: ":")
                if parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                    quietEnd = DateComponents(hour: h, minute: m)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func saveSettings() async {
        isSaving = true
        errorMessage = nil

        let startStr = quietHoursEnabled
            ? String(format: "%02d:%02d:00", quietStart.hour ?? 21, quietStart.minute ?? 0)
            : nil
        let endStr = quietHoursEnabled
            ? String(format: "%02d:%02d:00", quietEnd.hour ?? 7, quietEnd.minute ?? 0)
            : nil

        let update = ChildSettingsUpdate(
            canSnooze: canSnooze,
            maxSnoozesPerDay: maxSnoozes,
            canSubmitExcuses: canSubmitExcuses,
            quietHoursStart: startStr,
            quietHoursEnd: endStr
        )

        do {
            let _: ChildSettingsResponse = try await apiClient.request(
                .updateChildSettings(familyId: familyId, userId: childUserId, update: update)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
