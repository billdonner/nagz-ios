import SwiftUI

struct MemberRowView: View {
    let member: MemberDetail

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: member.role))
                .font(.title3)
                .foregroundStyle(iconColor(for: member.role))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName ?? "Unknown")
                    .font(.body)

                Text(member.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if member.status == .removed {
                Text("Removed")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }

    private func iconName(for role: FamilyRole) -> String {
        switch role {
        case .guardian: "person.badge.shield.checkmark"
        case .participant: "person.badge.clock"
        case .child: "person.fill"
        }
    }

    private func iconColor(for role: FamilyRole) -> Color {
        switch role {
        case .guardian: .blue
        case .participant: .orange
        case .child: .green
        }
    }
}
