import SwiftUI

struct DeliveryHistoryView: View {
    @State private var viewModel: DeliveryHistoryViewModel

    init(apiClient: APIClient, nagId: UUID) {
        _viewModel = State(initialValue: DeliveryHistoryViewModel(apiClient: apiClient, nagId: nagId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.deliveries.isEmpty {
                ContentUnavailableView {
                    Label("No Deliveries", systemImage: "paperplane")
                } description: {
                    Text("No notification deliveries recorded for this nag.")
                }
            } else {
                List(viewModel.deliveries) { delivery in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: delivery.channel == .push ? "bell.fill" : "message.fill")
                                    .foregroundStyle(delivery.channel == .push ? .blue : .green)
                                Text(delivery.channel.rawValue.uppercased())
                                    .font(.caption.weight(.semibold))
                            }
                            if let ref = delivery.providerRef {
                                Text(ref)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        StatusBadge(status: delivery.status)
                    }
                }
            }
        }
        .navigationTitle("Delivery History")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

private struct StatusBadge: View {
    let status: DeliveryStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.15))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .pending: .orange
        case .sent: .blue
        case .delivered: .green
        case .failed: .red
        }
    }
}
