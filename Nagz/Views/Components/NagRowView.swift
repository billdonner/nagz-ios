import SwiftUI

struct NagRowView: View {
    let nag: NagResponse
    var currentUserId: UUID?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: nag.category.iconName)
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(nag.description ?? nag.category.displayName)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let directionText = directionLabel {
                        Text(directionText)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if nag.recurrence != nil {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                    if nag.status == .completed, let completedAt = nag.completedAt {
                        Text("Done \(completedAt.agoDisplay)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(nag.dueAt.relativeDisplay)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if nag.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                StatusDot(status: nag.status)
            }
        }
        .padding(.vertical, 4)
    }

    private var directionLabel: String? {
        guard let userId = currentUserId else { return nil }
        if nag.creatorId == userId {
            let name = nag.recipientDisplayName ?? "someone"
            return "To: \(name) \u{2022}"
        } else {
            let name = nag.creatorDisplayName ?? "someone"
            return "From: \(name) \u{2022}"
        }
    }

    private var categoryColor: Color {
        switch nag.category {
        case .chores: .orange
        case .meds: .red
        case .homework: .blue
        case .appointments: .purple
        case .other: .gray
        }
    }
}

private struct StatusDot: View {
    let status: NagStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }

    private var color: Color {
        switch status {
        case .open: .blue
        case .completed: .green
        case .missed: .red
        case .cancelledRelationshipChange: .gray
        }
    }
}
