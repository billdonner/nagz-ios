import SwiftUI

struct AISummarySheet: View {
    let nags: [NagResponse]
    let currentUserId: UUID?
    let summaryText: String
    var filterLabel: String = "All"
    @Environment(\.dismiss) private var dismiss

    private var overdueNags: [NagResponse] {
        nags.filter { $0.status == .open && $0.dueAt < Date() }
            .sorted { $0.dueAt < $1.dueAt }
    }

    private var dueSoonNags: [NagResponse] {
        let now = Date()
        let twoHours = now.addingTimeInterval(2 * 3600)
        return nags.filter { $0.status == .open && $0.dueAt >= now && $0.dueAt <= twoHours }
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
                if isOpenFilter && !overdueNags.isEmpty {
                    Section {
                        ForEach(overdueNags) { nag in
                            urgencyRow(nag: nag, color: .red)
                        }
                    } header: {
                        Label("\(overdueNags.count) Overdue", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline.weight(.bold))
                    }
                }

                if isOpenFilter && !dueSoonNags.isEmpty {
                    Section {
                        ForEach(dueSoonNags) { nag in
                            urgencyRow(nag: nag, color: .orange)
                        }
                    } header: {
                        Label("\(dueSoonNags.count) Due Soon", systemImage: "clock.fill")
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

    private func urgencyRow(nag: NagResponse, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: nag.category.iconName)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(nag.description ?? nag.category.displayName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let userId = currentUserId {
                        if nag.creatorId == userId {
                            Text("To: \(nag.recipientDisplayName ?? "someone")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("From: \(nag.creatorDisplayName ?? "someone")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(nag.dueAt.relativeDisplay)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                }
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
