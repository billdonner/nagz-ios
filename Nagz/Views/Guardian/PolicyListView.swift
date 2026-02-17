import SwiftUI

struct PolicyListView: View {
    let apiClient: APIClient
    let familyId: UUID
    let members: [MemberDetail]

    @State private var viewModel: PolicyViewModel

    init(apiClient: APIClient, familyId: UUID, members: [MemberDetail]) {
        self.apiClient = apiClient
        self.familyId = familyId
        self.members = members
        _viewModel = State(initialValue: PolicyViewModel(apiClient: apiClient, familyId: familyId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.policies.isEmpty {
                ContentUnavailableView {
                    Label("No Policies", systemImage: "doc.text")
                } description: {
                    Text("No family policies have been created yet.")
                }
            } else {
                List(viewModel.policies) { policy in
                    NavigationLink(value: policy.id) {
                        PolicyRowView(policy: policy, members: members)
                    }
                }
            }
        }
        .navigationTitle("Policies")
        .navigationDestination(for: UUID.self) { policyId in
            if let policy = viewModel.policies.first(where: { $0.id == policyId }) {
                PolicyDetailView(
                    viewModel: viewModel,
                    policy: policy,
                    members: members
                )
            }
        }
        .task {
            await viewModel.loadPolicies()
        }
        .refreshable {
            await viewModel.loadPolicies()
        }
    }
}

private struct PolicyRowView: View {
    let policy: PolicyResponse
    let members: [MemberDetail]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(policy.strategyTemplate.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.headline)

            HStack {
                Text("Status:")
                    .foregroundStyle(.secondary)
                Text(policy.status.capitalized)
                    .foregroundStyle(policy.status == "active" ? .green : .secondary)
                    .fontWeight(.medium)
            }
            .font(.subheadline)

            HStack {
                Text("Owners:")
                    .foregroundStyle(.secondary)
                Text(ownerNames)
                    .lineLimit(1)
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }

    private var ownerNames: String {
        policy.owners.map { ownerId in
            members.first(where: { $0.userId == ownerId })?.displayName ?? ownerId.uuidString.prefix(8).description
        }.joined(separator: ", ")
    }
}
