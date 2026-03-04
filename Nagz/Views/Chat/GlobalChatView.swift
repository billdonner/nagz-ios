#if canImport(FoundationModels)
import SwiftUI
import NagzAI

struct GlobalChatView: View {
    let apiClient: APIClient
    let currentUserId: UUID
    let familyId: UUID?
    let userName: String
    let familyName: String?
    let memberNames: [String]

    @State private var viewModel = GlobalChatViewModel()
    @State private var overdueSummary: (overdueCount: Int, totalOpen: Int, mostUrgentLateDisplay: String?) = (0, 0, nil)
    @FocusState private var isInputFocused: Bool
    @AppStorage("nagz_ai_personality") private var personalityRaw: String = AIPersonality.standard.rawValue
    @AppStorage("selectedTab") private var selectedTab = 0

    private var personality: AIPersonality {
        AIPersonality(rawValue: personalityRaw) ?? .standard
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Overdue summary banner
                Button {
                    selectedTab = 1
                } label: {
                    overdueBanner
                }
                .buttonStyle(.plain)

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isGenerating {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.messages.count) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if viewModel.isGenerating {
                                proxy.scrollTo("typing", anchor: .bottom)
                            } else if let last = viewModel.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isGenerating) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if viewModel.isGenerating {
                                proxy.scrollTo("typing", anchor: .bottom)
                            } else if let last = viewModel.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .onTapGesture {
                    isInputFocused = false
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.purple)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }

                Divider()

                // Input bar
                HStack(spacing: 8) {
                    TextField("Ask me anything...", text: $viewModel.inputText, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit { sendAndDismiss() }

                    Button {
                        sendAndDismiss()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(canSend ? .blue : .gray)
                    }
                    .disabled(!canSend)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .navigationTitle("Talk to Nagz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Talk to Nagz")
                            .font(.headline)
                        Text(personality.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            setupIfNeeded()
            loadOverdueSummary()
        }
        .onChange(of: familyId) {
            // Family data arrived after initial load — re-setup with valid familyId
            if familyId != nil && !viewModel.hasFamily {
                viewModel.reset()
                setupIfNeeded()
            }
            loadOverdueSummary()
        }
    }

    private func setupIfNeeded() {
        if viewModel.messages.isEmpty {
            viewModel.setupSession(
                apiClient: apiClient,
                currentUserId: currentUserId,
                familyId: familyId,
                userName: userName,
                familyName: familyName,
                memberNames: memberNames,
                personality: personality
            )
        }
    }

    private func sendAndDismiss() {
        guard canSend else { return }
        isInputFocused = false
        Task { await viewModel.send() }
    }

    private var canSend: Bool {
        !viewModel.isGenerating && !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var overdueBanner: some View {
        if overdueSummary.overdueCount > 0 {
            let urgencyRatio = min(1.0, Double(overdueSummary.overdueCount) / max(1.0, Double(overdueSummary.totalOpen)))
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                Text("**\(overdueSummary.overdueCount) overdue** for you")
                if let late = overdueSummary.mostUrgentLateDisplay {
                    Text("· worst \(late) late")
                }
            }
            .lineLimit(1)
            .font(.caption)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                LinearGradient(
                    colors: [.blue, .purple.opacity(0.6 + urgencyRatio * 0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else if overdueSummary.totalOpen > 0 {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
                Text("**\(overdueSummary.totalOpen) open** for you · all on track")
            }
            .lineLimit(1)
            .font(.caption)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else {
            HStack(spacing: 4) {
                Image(systemName: "party.popper")
                    .font(.caption2)
                Text("All caught up!")
            }
            .lineLimit(1)
            .font(.caption)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.6), .blue.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    private func loadOverdueSummary() {
        Task {
            do {
                let response: PaginatedResponse<NagResponse> = try await apiClient.request(.listNags(status: .open, limit: 200))
                let now = Date()
                // Only count nags assigned TO me (received + self-nags), not ones I sent to others
                let myNags = response.items.filter { $0.recipientId == currentUserId }
                let overdueNags = myNags.filter { $0.dueAt < now }
                let mostUrgent = overdueNags.min(by: { $0.dueAt < $1.dueAt })

                var lateDisplay: String?
                if let urgent = mostUrgent {
                    let interval = now.timeIntervalSince(urgent.dueAt)
                    if interval < 3600 {
                        lateDisplay = "\(Int(interval / 60))m"
                    } else if interval < 86400 {
                        lateDisplay = "\(Int(interval / 3600))h"
                    } else {
                        lateDisplay = "\(Int(interval / 86400))d"
                    }
                }

                overdueSummary = (overdueNags.count, myNags.count, lateDisplay)
            } catch {
                // Silently fail — banner just won't update
            }
        }
    }
}

#endif
