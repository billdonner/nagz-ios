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

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.callout)
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
