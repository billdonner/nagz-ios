import SwiftUI

struct SafetyView: View {
    let apiClient: APIClient
    let members: [MemberDetail]
    let currentUserId: UUID
    let isGuardian: Bool
    @State private var viewModel: SafetyViewModel
    @State private var selectedTargetId: UUID?
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false
    @State private var showSuspendConfirmation = false

    init(apiClient: APIClient, members: [MemberDetail], currentUserId: UUID, isGuardian: Bool = false) {
        self.apiClient = apiClient
        self.members = members
        self.currentUserId = currentUserId
        self.isGuardian = isGuardian
        _viewModel = State(initialValue: SafetyViewModel(apiClient: apiClient))
    }

    private var otherMembers: [MemberDetail] {
        members.filter { $0.userId != currentUserId }
    }

    private var infoSection: some View {
        Section {
            Text("Use these tools if you feel unsafe or need to report inappropriate behavior.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var reportSection: some View {
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
    }

    private var blockSection: some View {
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
    }

    @ViewBuilder
    private var activeBlocksSection: some View {
        if !viewModel.blocks.isEmpty {
            Section("Active Blocks") {
                ForEach(viewModel.blocks) { block in
                    HStack {
                        let name = members.first(where: { $0.userId == block.targetId })?.displayName
                        Text(name ?? String(block.targetId.uuidString.prefix(8)) + "...")
                        Spacer()
                        Button("Unblock") {
                            Task { await viewModel.unblock(blockId: block.id) }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var suspendSection: some View {
        if isGuardian {
            Section("Suspend Relationship") {
                ForEach(otherMembers, id: \.userId) { member in
                    Button {
                        selectedTargetId = member.userId
                        showSuspendConfirmation = true
                    } label: {
                        HStack {
                            Text(member.displayName ?? "Unknown")
                            Spacer()
                            Image(systemName: "pause.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.errorMessage {
            Section {
                ErrorBanner(message: error)
            }
        }
    }

    var body: some View {
        List {
            infoSection
            reportSection
            blockSection
            activeBlocksSection
            suspendSection
            errorSection
        }
        .navigationTitle("Safety")
        .task { await viewModel.loadBlocks() }
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
        .confirmationDialog(
            "Suspend Relationship",
            isPresented: $showSuspendConfirmation,
            presenting: selectedTargetId
        ) { targetId in
            Button("Suspend", role: .destructive) {
                Task { await viewModel.suspendRelationship(memberId: targetId) }
            }
        } message: { targetId in
            let name = members.first(where: { $0.userId == targetId })?.displayName ?? "this member"
            Text("Suspend relationship with \(name)? They won't be able to create or receive nags.")
        }
        .alert("Done", isPresented: $viewModel.blockCreated) {
            Button("OK") {}
        } message: {
            Text("Member has been blocked.")
        }
        .alert("Relationship Suspended", isPresented: $viewModel.relationshipSuspended) {
            Button("OK") {}
        } message: {
            Text("The relationship has been suspended. No new nags can be created.")
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
                        ErrorBanner(message: error)
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
