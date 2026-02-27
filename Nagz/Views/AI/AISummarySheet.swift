import SwiftUI

struct AISummarySheet: View {
    let nags: [NagResponse]
    let currentUserId: UUID?
    let summaryText: String
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

    var body: some View {
        NavigationStack {
            List {
                if !overdueNags.isEmpty {
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

                if !dueSoonNags.isEmpty {
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
                    Label("AI Summary", systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                }

                Section {
                    HStack {
                        statBadge(count: openCount, label: "Open", color: .blue)
                        Spacer()
                        statBadge(count: completedCount, label: "Done", color: .green)
                        Spacer()
                        statBadge(count: overdueNags.count, label: "Overdue", color: .red)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("What Needs Attention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
