import SwiftUI

struct FamilyInsightsView: View {
    let familyId: UUID
    let currentUserId: UUID
    @Environment(\.aiService) private var aiService

    @State private var digest: DigestResponse?
    @State private var patterns: PatternsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var appeared = false

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
                        DigestSection(digest: digest, appeared: appeared)
                    }
                    if let patterns {
                        PatternsSection(patterns: patterns, appeared: appeared)
                    }
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.4)) {
                        appeared = true
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

        appeared = false
        isLoading = false
    }
}

// MARK: - Digest Section

private struct DigestSection: View {
    let digest: DigestResponse
    let appeared: Bool

    var body: some View {
        Section("Weekly Digest") {
            Text(digest.summaryText)
                .font(.body)
                .foregroundStyle(.primary)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: appeared)

            ForEach(Array(digest.memberSummaries.enumerated()), id: \.element.userId) { index, member in
                MemberDigestRow(member: member)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : -20)
                    .animation(.easeOut(duration: 0.4).delay(0.1 * Double(index + 1)), value: appeared)
            }

            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text("\(digest.totals.completed)/\(digest.totals.totalNags)")
                    .font(.body.monospacedDigit().weight(.semibold))
                completionRateText(digest.totals.completionRate, large: true)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.1 * Double(digest.memberSummaries.count + 1)), value: appeared)
        }
    }
}

private struct MemberDigestRow: View {
    let member: MemberSummary

    private var displayInitial: String {
        let name = member.displayName ?? "?"
        return String(name.prefix(1)).uppercased()
    }

    private var avatarColor: Color {
        if member.completionRate >= 0.7 { return .green }
        if member.completionRate >= 0.4 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(displayInitial)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(avatarColor)
                .clipShape(Circle())

            Text(member.displayName ?? "Member")
                .font(.body)
            Spacer()
            Text("\(member.completed)/\(member.totalNags)")
                .font(.body.monospacedDigit())
            completionRateText(member.completionRate, large: false)
        }
    }
}

private func completionRateText(_ rate: Double, large: Bool) -> some View {
    Text("\(Int(rate * 100))%")
        .font(large ? .callout.weight(.bold) : .caption.weight(.semibold))
        .padding(.horizontal, large ? 10 : 6)
        .padding(.vertical, large ? 4 : 2)
        .foregroundStyle(rate >= 0.7 ? .green : .red)
        .background((rate >= 0.7 ? Color.green : Color.red).opacity(0.12))
        .clipShape(Capsule())
}

// MARK: - Patterns Section

private struct PatternsSection: View {
    let patterns: PatternsResponse
    let appeared: Bool

    private var maxMissCount: Int {
        patterns.insights.map(\.missCount).max() ?? 1
    }

    var body: some View {
        Section("Your Patterns") {
            if patterns.insights.isEmpty {
                Text("No patterns detected yet.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(patterns.insights.enumerated()), id: \.element.dayOfWeek) { index, insight in
                    PatternDayRow(
                        insight: insight,
                        maxMissCount: maxMissCount,
                        appeared: appeared,
                        delay: 0.08 * Double(index)
                    )
                }
            }
        }
    }
}

private struct PatternDayRow: View {
    let insight: InsightItem
    let maxMissCount: Int
    let appeared: Bool
    let delay: Double

    @State private var barWidth: CGFloat = 0

    private var badgeColor: Color {
        if insight.missCount > 2 { return .red }
        if insight.missCount > 0 { return .orange }
        return .green
    }

    var body: some View {
        HStack {
            Text(insight.dayOfWeek)
                .font(.body)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                let fraction = maxMissCount > 0 ? CGFloat(insight.missCount) / CGFloat(maxMissCount) : 0
                RoundedRectangle(cornerRadius: 4)
                    .fill(badgeColor.opacity(0.25))
                    .frame(width: barWidth, height: 20)
                    .onChange(of: appeared) {
                        if appeared {
                            withAnimation(.easeOut(duration: 0.6).delay(delay)) {
                                barWidth = fraction * geo.size.width
                            }
                        }
                    }
                    .onAppear {
                        if appeared {
                            barWidth = fraction * geo.size.width
                        }
                    }
            }
            .frame(height: 20)

            Text("\(insight.missCount)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(badgeColor)
                .background(badgeColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -20)
        .animation(.easeOut(duration: 0.4).delay(delay), value: appeared)
    }
}
