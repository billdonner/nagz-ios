import SwiftUI

struct NagDetailView: View {
    @State private var viewModel: NagDetailViewModel
    @State private var completionNote = ""
    @State private var showNoteField = false
    @State private var showEditSheet = false
    let apiClient: APIClient
    let currentUserId: UUID
    let isGuardian: Bool

    init(apiClient: APIClient, nagId: UUID, currentUserId: UUID, isGuardian: Bool = false) {
        self.apiClient = apiClient
        _viewModel = State(initialValue: NagDetailViewModel(apiClient: apiClient, nagId: nagId))
        self.currentUserId = currentUserId
        self.isGuardian = isGuardian
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.nag == nil {
                ProgressView()
            } else if let error = viewModel.errorMessage, viewModel.nag == nil {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if let nag = viewModel.nag {
                List {
                    Section("Status") {
                        HStack {
                            Text("Status")
                            Spacer()
                            StatusPill(status: nag.status)
                        }
                        if let escalation = viewModel.escalation {
                            HStack {
                                Text("Escalation")
                                Spacer()
                                EscalationBadge(phase: escalation.currentPhase)
                            }
                        }
                    }

                    Section("Details") {
                        LabeledContent("Category") {
                            Label(nag.category.displayName, systemImage: nag.category.iconName)
                        }
                        LabeledContent("Due") {
                            Text(nag.dueAt.relativeDisplay)
                        }
                        LabeledContent("Completion") {
                            Text(nag.doneDefinition.displayName)
                        }
                        if let desc = nag.description {
                            Text(desc)
                        }
                    }

                    if nag.status == .open && nag.recipientId == currentUserId {
                        Section {
                            if nag.doneDefinition == .binaryWithNote {
                                if showNoteField {
                                    TextField("Add a note...", text: $completionNote, axis: .vertical)
                                        .lineLimit(2...4)
                                } else {
                                    Button("Add Note") {
                                        showNoteField = true
                                    }
                                }
                            }

                            Button {
                                Task {
                                    await viewModel.markComplete(
                                        note: completionNote.isEmpty ? nil : completionNote
                                    )
                                }
                            } label: {
                                if viewModel.isUpdating {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Label("Mark Complete", systemImage: "checkmark.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .disabled(viewModel.isUpdating)
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
            }
        }
        .navigationTitle("Nag Detail")
        .toolbar {
            if isGuardian, let nag = viewModel.nag, nag.status == .open {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let nag = viewModel.nag {
                EditNagView(apiClient: apiClient, nag: nag)
            }
        }
        .onChange(of: showEditSheet) { _, isPresented in
            if !isPresented {
                Task { await viewModel.load() }
            }
        }
        .task { await viewModel.load() }
    }
}

private struct StatusPill: View {
    let status: NagStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .open: .blue.opacity(0.15)
        case .completed: .green.opacity(0.15)
        case .missed: .red.opacity(0.15)
        case .cancelledRelationshipChange: .gray.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .open: .blue
        case .completed: .green
        case .missed: .red
        case .cancelledRelationshipChange: .gray
        }
    }
}
