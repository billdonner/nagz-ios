import SwiftUI

struct PolicyDetailView: View {
    @Bindable var viewModel: PolicyViewModel
    let policy: PolicyResponse
    let members: [MemberDetail]

    @State private var showApprovalSheet = false
    @State private var approvalComment = ""

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Strategy", value: policy.strategyTemplate.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                LabeledContent("Status", value: policy.status.capitalized)
            }

            Section("Owners") {
                ForEach(policy.owners, id: \.self) { ownerId in
                    let name = members.first(where: { $0.userId == ownerId })?.displayName ?? ownerId.uuidString.prefix(8).description
                    Label(name, systemImage: "person.fill")
                }
            }

            if !policy.constraints.isEmpty {
                Section("Constraints") {
                    ForEach(Array(policy.constraints.keys.sorted()), id: \.self) { key in
                        LabeledContent(
                            key.replacingOccurrences(of: "_", with: " ").capitalized,
                            value: "\(policy.constraints[key] ?? .string(""))"
                        )
                    }
                }
            }

            Section("Approvals") {
                if viewModel.approvals.isEmpty {
                    Text("No approvals yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.approvals) { approval in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                let name = members.first(where: { $0.userId == approval.approverId })?.displayName ?? approval.approverId.uuidString.prefix(8).description
                                Text(name)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(approval.approvedAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let comment = approval.comment, !comment.isEmpty {
                                Text(comment)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if policy.status == "active" {
                    Button("Add Approval") {
                        showApprovalSheet = true
                    }
                }
            }

            if let error = viewModel.error {
                Section {
                    ErrorBanner(message: error)
                }
            }
        }
        .navigationTitle("Policy")
        .task {
            await viewModel.loadApprovals(policyId: policy.id)
        }
        .sheet(isPresented: $showApprovalSheet) {
            NavigationStack {
                Form {
                    TextField("Comment (optional)", text: $approvalComment, axis: .vertical)
                        .lineLimit(3...6)
                }
                .navigationTitle("Approve Policy")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showApprovalSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Approve") {
                            Task {
                                await viewModel.createApproval(
                                    policyId: policy.id,
                                    comment: approvalComment.isEmpty ? nil : approvalComment
                                )
                                showApprovalSheet = false
                                approvalComment = ""
                            }
                        }
                        .disabled(viewModel.isSubmitting)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
