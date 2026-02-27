import SwiftUI

struct FamilyInsightsView: View {
    let familyId: UUID
    let currentUserId: UUID
    @Environment(\.aiService) private var aiService

    @State private var digest: DigestResponse?
    @State private var patterns: PatternsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if digest == nil && patterns == nil {
                ContentUnavailableView {
                    Label("No Insights", systemImage: "sparkles")
                } description: {
                    Text("AI insights will appear here once there is enough activity.")
                }
            } else {
                List {
                    if let digest {
                        DigestSection(digest: digest)
                    }
                    if let patterns {
                        PatternsSection(patterns: patterns)
                    }
                }
            }
        }
        .navigationTitle("AI Insights")
        .task { await loadInsights() }
        .refreshable { await loadInsights() }
    }

    private func loadInsights() async {
        guard let aiService else {
            errorMessage = "AI service unavailable"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        async let digestResult = try? aiService.digest(familyId: familyId)
        async let patternsResult = try? aiService.patterns(userId: currentUserId, familyId: familyId)

        let (d, p) = await (digestResult, patternsResult)
        digest = d
        patterns = p

        if d == nil && p == nil {
            errorMessage = nil // Show empty state instead
        }

        isLoading = false
    }
}

// MARK: - Digest Section

private struct DigestSection: View {
    let digest: DigestResponse

    var body: some View {
        Section("Weekly Digest") {
            Text(digest.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(digest.memberSummaries, id: \.userId) { member in
                MemberDigestRow(member: member)
            }

            HStack {
                Text("Total")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(digest.totals.completed)/\(digest.totals.totalNags)")
                    .font(.subheadline.monospacedDigit())
                completionRateText(digest.totals.completionRate)
            }
        }
    }
}

private struct MemberDigestRow: View {
    let member: MemberSummary

    var body: some View {
        HStack {
            Text(member.displayName ?? String(member.userId.uuidString.prefix(8)))
                .font(.subheadline)
            Spacer()
            Text("\(member.completed)/\(member.totalNags)")
                .font(.subheadline.monospacedDigit())
            completionRateText(member.completionRate)
        }
    }
}

private func completionRateText(_ rate: Double) -> some View {
    Text("\(Int(rate * 100))%")
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(rate >= 0.7 ? .green : .red)
        .background((rate >= 0.7 ? Color.green : Color.red).opacity(0.12))
        .clipShape(Capsule())
}

// MARK: - Patterns Section

private struct PatternsSection: View {
    let patterns: PatternsResponse

    var body: some View {
        Section("Your Patterns") {
            if patterns.insights.isEmpty {
                Text("No patterns detected yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(patterns.insights, id: \.dayOfWeek) { insight in
                    HStack {
                        Text(insight.dayOfWeek)
                            .font(.subheadline)
                        Spacer()
                        Text("\(insight.missCount) missed")
                            .font(.subheadline)
                            .foregroundStyle(insight.missCount > 2 ? .red : .secondary)
                    }
                }
            }
        }
    }
}
