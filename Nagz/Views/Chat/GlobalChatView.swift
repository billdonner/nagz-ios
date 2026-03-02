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
    @FocusState private var isInputFocused: Bool
    @AppStorage("nagz_ai_personality") private var personalityRaw: String = AIPersonality.standard.rawValue

    private var personality: AIPersonality {
        AIPersonality(rawValue: personalityRaw) ?? .standard
    }

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
                .onTapGesture {
                    isInputFocused = false
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isInputFocused = false
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
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
    }

    private func sendAndDismiss() {
        guard canSend else { return }
        isInputFocused = false
        Task { await viewModel.send() }
    }

    private var canSend: Bool {
        !viewModel.isGenerating && !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#endif
