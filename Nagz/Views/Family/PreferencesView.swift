import SwiftUI

struct PreferencesView: View {
    @State private var viewModel: PreferencesViewModel
    @Environment(\.dismiss) private var dismiss

    init(apiClient: APIClient, familyId: UUID) {
        _viewModel = State(initialValue: PreferencesViewModel(apiClient: apiClient, familyId: familyId))
    }

    var body: some View {
        Form {
            Section("Features") {
                Toggle("Gamification", isOn: $viewModel.gamificationEnabled)
                Text("Enable points, streaks, and leaderboards for family members.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Quiet Hours") {
                Toggle("Quiet Hours", isOn: $viewModel.quietHoursEnabled)
                if viewModel.quietHoursEnabled {
                    LabeledContent("Start") {
                        TextField("Start", text: $viewModel.quietHoursStart)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    LabeledContent("End") {
                        TextField("End", text: $viewModel.quietHoursEnd)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Text("No push notifications during quiet hours.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notifications") {
                Picker("Frequency", selection: $viewModel.notificationFrequency) {
                    Text("Always").tag("always")
                    Text("Once per phase").tag("once_per_phase")
                    Text("Daily digest").tag("daily_digest")
                }

                Picker("Channel", selection: $viewModel.deliveryChannel) {
                    Text("Push").tag("push")
                    Text("SMS").tag("sms")
                    Text("Both").tag("both")
                }

                Text("Controls how often and where nag notifications are delivered.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = viewModel.errorMessage {
                Section {
                    ErrorBanner(message: error)
                }
            }

            Section {
                Button {
                    Task { await viewModel.save() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Save Preferences").frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .navigationTitle("Preferences")
        .task { await viewModel.load() }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
    }
}
