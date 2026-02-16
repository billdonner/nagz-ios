import SwiftUI

struct MemberRowView: View {
    let member: MemberDetail

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: member.role == .guardian ? "person.badge.shield.checkmark" : "person.fill")
                .font(.title3)
                .foregroundStyle(member.role == .guardian ? .blue : .green)
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
}
