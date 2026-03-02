import SwiftUI

// MARK: - Chat Bubble

struct ChatBubble: View {
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

struct TypingIndicator: View {
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
