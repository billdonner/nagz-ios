import SwiftUI

struct SafetyView: View {
    let apiClient: APIClient
    let members: [MemberDetail]
    let currentUserId: UUID
    @State private var viewModel: SafetyViewModel
    @State private var selectedTargetId: UUID?
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false

    init(apiClient: APIClient, members: [MemberDetail], currentUserId: UUID) {
        self.apiClient = apiClient
        self.members = members
        self.currentUserId = currentUserId
        _viewModel = State(initialValue: SafetyViewModel(apiClient: apiClient))
    }

    private var otherMembers: [MemberDetail] {
        members.filter { $0.userId != currentUserId }
    }

    var body: some View {
        List {
            Section {
                Text("Use these tools if you feel unsafe or need to report inappropriate behavior.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Report a Member") {
                ForEach(otherMembers, id: \.userId) { member in
                    Button {
                        selectedTargetId = member.userId
                        showReportSheet = true
                    } label: {
                        HStack {
                            Text(member.displayName ?? "Unknown")
                            Spacer()
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Section("Block a Member") {
                ForEach(otherMembers, id: \.userId) { member in
                    Button {
                        selectedTargetId = member.userId
                        showBlockConfirmation = true
                    } label: {
                        HStack {
                            Text(member.displayName ?? "Unknown")
                            Spacer()
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
            }
        }
        .navigationTitle("Safety")
        .sheet(isPresented: $showReportSheet) {
            if let targetId = selectedTargetId {
                ReportSheet(
                    viewModel: viewModel,
                    targetId: targetId,
                    targetName: members.first(where: { $0.userId == targetId })?.displayName ?? "Unknown"
                )
            }
        }
        .confirmationDialog(
            "Block Member",
            isPresented: $showBlockConfirmation,
            presenting: selectedTargetId
        ) { targetId in
            Button("Block", role: .destructive) {
                Task { await viewModel.blockUser(targetId: targetId) }
            }
        } message: { targetId in
            let name = members.first(where: { $0.userId == targetId })?.displayName ?? "this member"
            Text("Block \(name)? They won't be able to interact with you.")
        }
        .alert("Done", isPresented: $viewModel.blockCreated) {
            Button("OK") {}
        } message: {
            Text("Member has been blocked.")
        }
    }
}

private struct ReportSheet: View {
    @Bindable var viewModel: SafetyViewModel
    let targetId: UUID
    let targetName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Report \(targetName)") {
                    TextField("Describe the issue...", text: $viewModel.reportReason, axis: .vertical)
                        .lineLimit(3...8)
                }
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle("Report Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await viewModel.submitAbuseReport(targetId: targetId)
                            if viewModel.reportCreated { dismiss() }
                        }
                    }
                    .disabled(viewModel.reportReason.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSubmitting)
                }
            }
        }
    }
}
