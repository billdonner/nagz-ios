import SwiftUI

struct IncentiveRulesView: View {
    @State private var viewModel: IncentiveRulesViewModel

    init(apiClient: APIClient, familyId: UUID) {
        _viewModel = State(initialValue: IncentiveRulesViewModel(apiClient: apiClient, familyId: familyId))
    }

    var body: some View {
        List {
            if viewModel.rules.isEmpty && !viewModel.isLoading {
                ContentUnavailableView {
                    Label("No Rules", systemImage: "gift")
                } description: {
                    Text("Create incentive rules to reward family members for completing nags.")
                }
            }

            ForEach(viewModel.rules) { rule in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(conditionDescription(rule.condition))
                            .font(.body)
                        Spacer()
                        Text(rule.status.capitalized)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(rule.status == "active" ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                            .foregroundStyle(rule.status == "active" ? .green : .gray)
                            .clipShape(Capsule())
                    }
                    Text(actionDescription(rule.action))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Approval: \(rule.approvalMode.displayName)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).font(.callout)
            }
        }
        .navigationTitle("Incentive Rules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateIncentiveRuleSheet(viewModel: viewModel)
        }
    }

    private func conditionDescription(_ condition: [String: AnyCodableValue]) -> String {
        let type = condition["type"]?.stringValue ?? "event"
        if case .int(let count) = condition["count"] {
            return "Complete \(count) \(type.replacingOccurrences(of: "_", with: " "))s"
        }
        return type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func actionDescription(_ action: [String: AnyCodableValue]) -> String {
        let type = action["type"]?.stringValue ?? "reward"
        if case .int(let amount) = action["amount"] {
            return "\(type.replacingOccurrences(of: "_", with: " ").capitalized): \(amount)"
        }
        return type.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct CreateIncentiveRuleSheet: View {
    @Bindable var viewModel: IncentiveRulesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Condition") {
                    Picker("Event Type", selection: $viewModel.newConditionType) {
                        Text("Nag Completed").tag("nag_completed")
                        Text("Streak Reached").tag("streak_reached")
                    }
                    Stepper("Count: \(viewModel.newConditionCount)", value: $viewModel.newConditionCount, in: 1...100)
                }

                Section("Reward") {
                    Picker("Reward Type", selection: $viewModel.newActionType) {
                        Text("Bonus Points").tag("bonus_points")
                        Text("Badge").tag("badge")
                    }
                    Stepper("Amount: \(viewModel.newActionAmount)", value: $viewModel.newActionAmount, in: 1...1000, step: 10)
                }

                Section("Approval") {
                    Picker("Mode", selection: $viewModel.newApprovalMode) {
                        ForEach(IncentiveApprovalMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await viewModel.createRule() }
                    }
                    .disabled(viewModel.isCreating)
                }
            }
        }
    }
}
