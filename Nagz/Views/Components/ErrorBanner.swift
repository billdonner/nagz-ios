import SwiftUI

/// Reusable error display with optional retry button.
struct ErrorBanner: View {
    let message: String
    var retryAction: (() async -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)

            if let retryAction {
                Button("Retry") {
                    Task { await retryAction() }
                }
                .buttonStyle(.bordered)
                .font(.callout)
            }
        }
        .padding(.vertical, 4)
    }
}
