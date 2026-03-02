import SwiftUI

struct NagRowView: View {
    let nag: NagResponse
    var currentUserId: UUID?

    private var urgency: Urgency {
        Urgency(dueAt: nag.dueAt, status: nag.status)
    }

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
                            .foregroundStyle(urgency.textColor)
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
        .padding(.horizontal, 4)
        .background(urgency.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) {
            urgency.accentBar
        }
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

// MARK: - Urgency

private enum Urgency {
    case calm, approaching, dueSoon, overdue, critical

    init(dueAt: Date, status: NagStatus) {
        guard status == .open else { self = .calm; return }
        let interval = dueAt.timeIntervalSince(Date())
        switch interval {
        case let t where t > 24 * 3600: self = .calm
        case let t where t > 2 * 3600:  self = .approaching
        case let t where t > 0:         self = .dueSoon
        case let t where t > -3600:     self = .overdue
        default:                         self = .critical
        }
    }

    var backgroundColor: Color {
        switch self {
        case .calm:        Color.clear
        case .approaching: Color.blue.opacity(0.04)
        case .dueSoon:     Color.yellow.opacity(0.08)
        case .overdue:     Color.orange.opacity(0.10)
        case .critical:    Color.red.opacity(0.10)
        }
    }

    var textColor: Color {
        switch self {
        case .calm:        .secondary
        case .approaching: .blue
        case .dueSoon:     .orange
        case .overdue:     .orange
        case .critical:    .red
        }
    }

    @ViewBuilder
    var accentBar: some View {
        switch self {
        case .calm, .approaching:
            EmptyView()
        case .dueSoon:
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.yellow)
                .frame(width: 3)
        case .overdue:
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.orange)
                .frame(width: 3)
        case .critical:
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.red)
                .frame(width: 3)
        }
    }
}
