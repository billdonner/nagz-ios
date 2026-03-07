import SwiftUI

struct AISummarySheet: View {
    let nags: [NagResponse]
    let currentUserId: UUID?
    let summaryText: String
    var filterLabel: String = "All"
    @Environment(\.dismiss) private var dismiss

    // Nags YOU need to act on (overdue)
    private var overdueForMe: [NagResponse] {
        guard let userId = currentUserId else {
            return nags.filter { $0.status == .open && $0.dueAt < Date() }.sorted { $0.dueAt < $1.dueAt }
        }
        return nags.filter { $0.status == .open && $0.dueAt < Date() && $0.recipientId == userId }
            .sorted { $0.dueAt < $1.dueAt }
    }

    // Nags you assigned to others that are overdue (less urgent for you)
    private var overdueAssigned: [NagResponse] {
        guard let userId = currentUserId else { return [] }
        return nags.filter { $0.status == .open && $0.dueAt < Date() && $0.recipientId != userId }
            .sorted { $0.dueAt < $1.dueAt }
    }

    private var dueSoonNags: [NagResponse] {
        let now = Date()
        let twoHours = now.addingTimeInterval(2 * 3600)
        guard let userId = currentUserId else {
            return nags.filter { $0.status == .open && $0.dueAt >= now && $0.dueAt <= twoHours }.sorted { $0.dueAt < $1.dueAt }
        }
        return nags.filter { $0.status == .open && $0.dueAt >= now && $0.dueAt <= twoHours && $0.recipientId == userId }
            .sorted { $0.dueAt < $1.dueAt }
    }

    private var openCount: Int {
        nags.filter { $0.status == .open }.count
    }

    private var completedCount: Int {
        nags.filter { $0.status == .completed }.count
    }

    private var isOpenFilter: Bool {
        filterLabel == "Open" || filterLabel == "All"
    }

    var body: some View {
        NavigationStack {
            List {
                if isOpenFilter && !overdueForMe.isEmpty {
                    Section {
                        ForEach(overdueForMe) { nag in
                            urgencyRow(nag: nag, color: .red, showFrom: true)
                        }
                    } header: {
                        Label("\(overdueForMe.count) Overdue — Your List", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline.weight(.bold))
                    }
                }

                if isOpenFilter && !overdueAssigned.isEmpty {
                    Section {
                        ForEach(overdueAssigned) { nag in
                            assignedOverdueRow(nag: nag)
                        }
                    } header: {
                        Text("You Assigned — \(overdueAssigned.count) Late")
                            .foregroundStyle(.secondary)
                            .font(.caption.weight(.medium))
                    }
                }

                if isOpenFilter && !dueSoonNags.isEmpty {
                    Section {
                        ForEach(dueSoonNags) { nag in
                            urgencyRow(nag: nag, color: .orange, showFrom: true)
                        }
                    } header: {
                        Label("\(dueSoonNags.count) Due Soon — Your List", systemImage: "clock.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline.weight(.bold))
                    }
                }

                Section {
                    Text(summaryText)
                        .font(.body)
                } header: {
                    Label("AI Summary — \(filterLabel)", systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                }

                Section {
                    HStack {
                        statBadge(count: nags.count, label: filterLabel, color: filterColor)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var navigationTitle: String {
        switch filterLabel {
        case "All": "What Needs Attention"
        case "Open": "Open Nagz"
        case "Completed": "Completed Nagz"
        case "Missed": "Missed Nagz"
        default: "Nagz — \(filterLabel)"
        }
    }

    private var filterColor: Color {
        switch filterLabel {
        case "Open": .blue
        case "Completed": .green
        case "Missed": .red
        default: .primary
        }
    }

    private func urgencyRow(nag: NagResponse, color: Color, showFrom: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: nag.category.iconName)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(nag.description ?? nag.category.displayName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if showFrom, let userId = currentUserId, nag.creatorId != userId,
                       let name = nag.creatorDisplayName {
                        Text("from \(name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(nag.dueAt.relativeDisplay)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                }
            }
        }
    }

    private func assignedOverdueRow(nag: NagResponse) -> some View {
        HStack(spacing: 10) {
            Image(systemName: nag.category.iconName)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(nag.description ?? nag.category.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(nag.recipientDisplayName ?? "someone") · \(nag.dueAt.relativeDisplay)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func statBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
