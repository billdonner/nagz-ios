import SwiftUI

struct NagRowView: View {
    let nag: NagResponse

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

                Text(nag.dueAt.relativeDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusDot(status: nag.status)
        }
        .padding(.vertical, 4)
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
