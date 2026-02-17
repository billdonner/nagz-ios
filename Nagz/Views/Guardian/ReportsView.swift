import SwiftUI

struct ReportsView: View {
    @State private var viewModel: ReportsViewModel

    init(apiClient: APIClient, familyId: UUID) {
        _viewModel = State(initialValue: ReportsViewModel(apiClient: apiClient, familyId: familyId))
    }

    var body: some View {
        List {
            if let metrics = viewModel.metrics {
                Section("Overall Metrics") {
                    LabeledContent("Total Nags", value: "\(metrics.totalNags)")
                    LabeledContent("Completed", value: "\(metrics.completed)")
                    LabeledContent("Missed", value: "\(metrics.missed)")
                    LabeledContent("Completion Rate") {
                        Text("\(Int(metrics.completionRate * 100))%")
                            .foregroundStyle(metrics.completionRate >= 0.7 ? .green : .red)
                            .fontWeight(.semibold)
                    }
                }
            }

            if let weekly = viewModel.weeklyReport {
                Section("Weekly Report") {
                    LabeledContent("Period Start") {
                        Text(weekly.periodStart.relativeDisplay)
                    }
                    LabeledContent("Total", value: "\(weekly.metrics.totalNags)")
                    LabeledContent("Completed", value: "\(weekly.metrics.completed)")
                    LabeledContent("Missed", value: "\(weekly.metrics.missed)")
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("Reports")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
