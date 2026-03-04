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
                        HStack(spacing: 2) {
                            if let icon = directionIcon {
                                Image(systemName: icon)
                                    .font(.caption2.weight(.bold))
                            }
                            Text(directionText)
                        }
                        .font(.caption)
                        .foregroundStyle(directionColor ?? .secondary)
                    }
                    if nag.recurrence != nil {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                    if let committedAt = nag.committedAt, nag.status == .open {
                        HStack(spacing: 2) {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.caption2)
                            Text(committedAt.relativeDisplay)
                                .font(.caption)
                        }
                        .foregroundStyle(.purple)
                    }
                    if nag.status == .completed, let completedAt = nag.completedAt {
                        Text("Done \(completedAt.agoDisplay)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(nag.dueAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(urgency.textColor)
                    }
                }
            }

            Spacer()

            if nag.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if nag.recipientDismissedAt != nil {
                Image(systemName: "eye.slash")
                    .foregroundStyle(.secondary)
            } else {
                StatusDot(status: nag.status)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background {
            // Layer: direction tint underneath, urgency on top
            directionBackground
                .overlay(urgency.backgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(nag.status == .withdrawn ? 0.5 : 1.0)
        .overlay(alignment: .leading) {
            // Sidebar always shows direction color (blue/orange/purple)
            if let color = directionColor {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 4)
            }
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

    private var directionIcon: String? {
        guard let userId = currentUserId else { return nil }
        if nag.creatorId == userId && nag.recipientId == userId {
            return "arrow.uturn.backward" // self-nag
        } else if nag.recipientId == userId {
            return "arrow.down.left"       // received
        } else if nag.creatorId == userId {
            return "arrow.up.right"        // sent
        }
        return nil
    }

    private var directionBackground: Color {
        guard let userId = currentUserId else { return .clear }
        if nag.creatorId == userId && nag.recipientId == userId {
            return .purple.opacity(0.03)
        } else if nag.recipientId == userId {
            return .blue.opacity(0.03)
        } else if nag.creatorId == userId {
            return .orange.opacity(0.03)
        }
        return .clear
    }

    private var directionColor: Color? {
        guard let userId = currentUserId else { return nil }
        if nag.creatorId == userId && nag.recipientId == userId {
            return .purple  // self-nag
        } else if nag.recipientId == userId {
            return .blue    // received
        } else if nag.creatorId == userId {
            return .orange  // sent
        }
        return nil
    }

    private var categoryColor: Color {
        switch nag.category {
        case .chores: .brown
        case .meds: .pink
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
        case .missed: .orange
        case .cancelledRelationshipChange, .withdrawn: .gray
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
        case .approaching: Color.clear
        case .dueSoon:     Color.yellow.opacity(0.04)
        case .overdue:     Color.orange.opacity(0.04)
        case .critical:    Color.orange.opacity(0.06)
        }
    }

    var textColor: Color {
        switch self {
        case .calm:        .secondary
        case .approaching: .secondary
        case .dueSoon:     .orange
        case .overdue:     .orange
        case .critical:    .red
        }
    }

    var hasAccentBar: Bool {
        switch self {
        case .calm, .approaching: false
        case .dueSoon, .overdue, .critical: true
        }
    }

    @ViewBuilder
    var accentBar: some View {
        switch self {
        case .calm, .approaching, .dueSoon:
            EmptyView()
        case .overdue:
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.orange.opacity(0.6))
                .frame(width: 3)
        case .critical:
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.orange)
                .frame(width: 3)
        }
    }
}
