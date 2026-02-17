import SwiftUI

struct ConsentListView: View {
    @State private var viewModel: ConsentViewModel

    init(apiClient: APIClient, familyId: UUID) {
        _viewModel = State(initialValue: ConsentViewModel(apiClient: apiClient, familyId: familyId))
    }

    var body: some View {
        List {
            ForEach(ConsentType.allCases, id: \.self) { type in
                let granted = viewModel.consents.first { $0.consentType == type }
                HStack {
                    VStack(alignment: .leading) {
                        Text(type.displayName)
                            .font(.body)
                        Text(type.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let consent = granted {
                        Button("Revoke", role: .destructive) {
                            Task { await viewModel.revokeConsent(consent) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("Grant") {
                            Task { await viewModel.grantConsent(type) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .disabled(viewModel.isUpdating)
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).font(.callout)
            }
        }
        .navigationTitle("Consents")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }
}
