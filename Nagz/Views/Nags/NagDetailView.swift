import SwiftUI
import NagzAI

struct NagDetailView: View {
    @State private var viewModel: NagDetailViewModel
    @State private var completionNote = ""
    @State private var showNoteField = false
    @State private var showEditSheet = false
    @State private var showExcuseSheet = false
    @State private var excuseText = ""
    @State private var showCompletionCelebration = false
    @State private var showExcuseResponse = false
    @State private var lastExcuseResponse: String?
    @State private var showChat = false
    @State private var showCommitTimePicker = false
    @AppStorage("nagz_ai_personality") private var personalityRaw: String = AIPersonality.standard.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.databaseManager) private var databaseManager
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
                        LabeledContent("Category", value: nag.category.displayName)
                        LabeledContent("Due") {
                            TimelineView(.periodic(from: .now, by: 30)) { _ in
                                Text(nag.dueAt.relativeDisplay)
                                    .foregroundStyle(nag.status == .open && nag.dueAt < Date() ? .orange : .secondary)
                            }
                        }
                        LabeledContent("Completion", value: nag.doneDefinition.displayName)
                        if let recurrence = nag.recurrence {
                            LabeledContent("Repeats", value: recurrence.displayName)
                        }
                        if let committedAt = nag.committedAt {
                            LabeledContent("Committed") {
                                TimelineView(.periodic(from: .now, by: 30)) { _ in
                                    Text(committedAt.relativeDisplay)
                                        .foregroundStyle(.purple)
                                }
                            }
                        }
                    }

                    if NagzAI.Router.isAppleIntelligenceAvailable {
                        AIInsightsSection(nagId: nag.id, nag: nag)
                    }

                    // Actions (recipient only, open nags)
                    if nag.status == .open && nag.recipientId == currentUserId {
                        Section("Actions") {
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
                                    if viewModel.errorMessage == nil {
                                        withAnimation(.spring(duration: 0.4)) {
                                            showCompletionCelebration = true
                                        }
                                        try? await Task.sleep(for: .seconds(1.5))
                                        dismiss()
                                    }
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
                            .disabled(viewModel.isUpdating || showCompletionCelebration)

                            Button {
                                showExcuseSheet = true
                            } label: {
                                Label("Submit Excuse", systemImage: "text.bubble")
                                    .frame(maxWidth: .infinity)
                            }

                            Button {
                                Task { await viewModel.snooze(minutes: 15) }
                            } label: {
                                if viewModel.isUpdating {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Label("Snooze 15 min", systemImage: "clock.badge.xmark")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .disabled(viewModel.isUpdating)

                            Button {
                                showCommitTimePicker = true
                            } label: {
                                Label("I'll do it by...", systemImage: "clock.badge.checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    // Creator: Withdraw button (open nags only)
                    if nag.status == .open && nag.creatorId == currentUserId && nag.creatorId != nag.recipientId {
                        Section {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.withdraw()
                                    if viewModel.errorMessage == nil {
                                        dismiss()
                                    }
                                }
                            } label: {
                                if viewModel.isUpdating {
                                    ProgressView().frame(maxWidth: .infinity)
                                } else {
                                    Label("Withdraw Nag", systemImage: "arrow.uturn.backward")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .disabled(viewModel.isUpdating)
                        }
                    }

                    // Recipient: Dismiss / Undismiss button (open nags only)
                    if nag.status == .open && nag.recipientId == currentUserId && nag.creatorId != nag.recipientId {
                        Section {
                            if nag.recipientDismissedAt != nil {
                                Button {
                                    Task { await viewModel.undismiss() }
                                } label: {
                                    Label("Undo Dismiss", systemImage: "eye")
                                        .frame(maxWidth: .infinity)
                                }
                                .disabled(viewModel.isUpdating)
                            } else {
                                Button {
                                    Task {
                                        await viewModel.dismiss()
                                        if viewModel.errorMessage == nil {
                                            dismiss()
                                        }
                                    }
                                } label: {
                                    Label("Dismiss", systemImage: "eye.slash")
                                        .frame(maxWidth: .infinity)
                                }
                                .disabled(viewModel.isUpdating)
                            }
                        }
                    }

                    // Excuses list
                    if !viewModel.excuses.isEmpty {
                        Section("Excuses") {
                            ForEach(viewModel.excuses) { excuse in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(excuse.summary)
                                        .font(.body)
                                    if let at = excuse.at {
                                        Text(at.relativeDisplay)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // Guardian actions
                    if isGuardian {
                        Section("Guardian Actions") {
                            if nag.status == .open {
                                Button {
                                    Task { await viewModel.recomputeEscalation() }
                                } label: {
                                    if viewModel.isRecomputing {
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Label("Recompute Escalation", systemImage: "arrow.clockwise")
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .disabled(viewModel.isRecomputing)
                            }
                            NavigationLink {
                                DeliveryHistoryView(apiClient: apiClient, nagId: nag.id)
                            } label: {
                                Label("Delivery History", systemImage: "paperplane")
                            }
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Section {
                            ErrorBanner(message: error)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.nag?.description ?? viewModel.nag?.category.displayName ?? "Nag Detail")
        .toolbar {
            #if canImport(FoundationModels)
            if let nag = viewModel.nag,
               NagzAI.Router.isAppleIntelligenceAvailable,
               nag.status == .open,
               nag.recipientId == currentUserId {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showChat = true
                    } label: {
                        Label("Chat", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }
            #endif
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
        .sheet(isPresented: $showExcuseSheet) {
            ExcuseSubmitSheet(
                excuseText: $excuseText,
                isSubmitting: viewModel.isUpdating,
                errorMessage: viewModel.errorMessage,
                onSubmit: {
                    Task {
                        await viewModel.submitExcuse(text: excuseText)
                        if viewModel.errorMessage == nil {
                            lastExcuseResponse = viewModel.excuses.last?.summary ?? excuseText
                            excuseText = ""
                            showExcuseSheet = false
                            showExcuseResponse = true
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showExcuseResponse) {
            ExcuseResponseSheet(excuseSummary: lastExcuseResponse ?? "")
        }
        .sheet(isPresented: $showCommitTimePicker) {
            CommitTimePickerSheet { date in
                Task {
                    await viewModel.commitTime(date: date)
                    showCommitTimePicker = false
                }
            }
        }
        #if canImport(FoundationModels)
        .sheet(isPresented: $showChat) {
            if let nag = viewModel.nag {
                NagChatView(
                    nag: nag,
                    apiClient: apiClient,
                    personality: AIPersonality(rawValue: personalityRaw) ?? .standard,
                    databaseManager: databaseManager,
                    onDismissReload: {
                        Task { await viewModel.load() }
                    }
                )
            }
        }
        #endif
        .onChange(of: showEditSheet) { _, isPresented in
            if !isPresented {
                Task { await viewModel.load() }
            }
        }
        .task { await viewModel.load() }
        .overlay {
            if showCompletionCelebration {
                CompletionCelebrationView()
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

private struct CompletionCelebrationView: View {
    @State private var checkScale = 0.3
    @State private var ringScale = 0.8
    @State private var textOpacity = 0.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 4)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringScale)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .scaleEffect(checkScale)
                }

                Text("Done!")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) {
                checkScale = 1.0
                ringScale = 1.2
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.3)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                ringScale = 1.5
            }
        }
    }
}

private struct ExcuseSubmitSheet: View {
    @Binding var excuseText: String
    let isSubmitting: Bool
    let errorMessage: String?
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Why can't you complete this nag?") {
                    TextField("Explain your reason...", text: $excuseText, axis: .vertical)
                        .lineLimit(3...8)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Submit Excuse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Submit") { onSubmit() }
                            .disabled(excuseText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}

private struct ExcuseResponseSheet: View {
    let excuseSummary: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Excuse Sent")
                    .font(.title2.weight(.semibold))

                Text("\"\(excuseSummary)\"")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .italic()

                Text("The person who nagged you will review your excuse and decide what happens next.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
            .navigationTitle("Excuse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(10))
            dismiss()
        }
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
        case .missed: .orange.opacity(0.15)
        case .cancelledRelationshipChange, .withdrawn: .gray.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .open: .blue
        case .completed: .green
        case .missed: .orange
        case .cancelledRelationshipChange, .withdrawn: .gray
        }
    }
}
