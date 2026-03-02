#if canImport(FoundationModels)
import SwiftUI
import NagzAI

struct NagChatView: View {
    let nag: NagResponse
    let apiClient: APIClient
    let personality: AIPersonality
    let onDismissReload: () -> Void

    @State private var viewModel = NagChatViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }

                Divider()

                // Input bar
                HStack(spacing: 8) {
                    TextField("Type a message...", text: $viewModel.inputText, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))

                    Button {
                        Task { await viewModel.send() }
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
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Chat")
                            .font(.headline)
                        Text(personality.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if viewModel.nagWasMutated {
                            onDismissReload()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .onAppear {
            viewModel.setupSession(
                nag: nag,
                apiClient: apiClient,
                personality: personality,
                onMutated: { }
            )
        }
    }

    private var canSend: Bool {
        !viewModel.isGenerating && !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .assistant:
            HStack {
                Text(message.content)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer(minLength: 48)
            }

        case .user:
            HStack {
                Spacer(minLength: 48)
                Text(message.content)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

        case .system:
            Text(message.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color(.systemGray3))
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset(for: i))
            }
        }
        .padding(12)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }

    private func animationOffset(for index: Int) -> CGFloat {
        let delay = Double(index) * 0.15
        let progress = max(0, phase - delay)
        return -4 * progress
    }
}

#endif
