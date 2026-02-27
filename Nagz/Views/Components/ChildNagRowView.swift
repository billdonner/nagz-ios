import SwiftUI

/// Big, colorful nag card for the child UI.
struct ChildNagRowView: View {
    let nag: NagResponse
    let onComplete: () async -> Void

    @State private var isCompleting = false

    private var categoryColor: Color {
        switch nag.category {
        case .chores: .blue
        case .meds: .red
        case .homework: .purple
        case .appointments: .orange
        case .other: .gray
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: nag.category.iconName)
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(categoryColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(nag.description ?? nag.category.displayName)
                    .font(.headline)
                    .lineLimit(2)

                Text(nag.dueAt, style: .relative)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isCompleting = true
                Task {
                    await onComplete()
                    isCompleting = false
                }
            } label: {
                if isCompleting {
                    ProgressView()
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)
                }
            }
            .disabled(isCompleting)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
