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

    private var urgency: ChildUrgency {
        ChildUrgency(dueAt: nag.dueAt, status: nag.status)
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
                    .foregroundStyle(urgency.textColor)
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
        .shadow(color: urgency.shadowColor, radius: urgency.shadowRadius, y: 2)
    }
}

// MARK: - Child Urgency

private enum ChildUrgency {
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

    var textColor: Color {
        switch self {
        case .calm:        .secondary
        case .approaching: .blue
        case .dueSoon:     .orange
        case .overdue:     .orange
        case .critical:    .red
        }
    }

    var shadowColor: Color {
        switch self {
        case .calm:        .black.opacity(0.08)
        case .approaching: .blue.opacity(0.12)
        case .dueSoon:     .orange.opacity(0.15)
        case .overdue:     .orange.opacity(0.20)
        case .critical:    .red.opacity(0.25)
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .calm, .approaching: 4
        case .dueSoon:            6
        case .overdue:            8
        case .critical:           10
        }
    }
}
