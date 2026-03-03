import NagzAI
import SwiftUI

struct GamificationView: View {
    @State private var viewModel: GamificationViewModel
    let members: [MemberDetail]

    init(apiClient: APIClient, familyId: UUID, userId: UUID, members: [MemberDetail]) {
        _viewModel = State(initialValue: GamificationViewModel(apiClient: apiClient, familyId: familyId, userId: userId))
        self.members = members
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.summary == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isNotEnabled {
                ContentUnavailableView {
                    Label("Gamification Off", systemImage: "trophy")
                } description: {
                    Text("Gamification is not enabled for this family. A guardian can turn it on in Family \u{2192} Preferences.")
                }
            } else if let error = viewModel.errorMessage, viewModel.summary == nil {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                List {
                    if !viewModel.nudges.isEmpty {
                        nudgesSection
                    }

                    if let summary = viewModel.summary {
                        summarySection(summary)
                    }

                    if let board = viewModel.leaderboard, !board.leaderboard.isEmpty {
                        leaderboardSection(board)
                    }

                    if !viewModel.badges.isEmpty {
                        badgesSection
                    }

                    if !viewModel.events.isEmpty {
                        recentEventsSection
                    }
                }
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle("Gamification")
        .task { await viewModel.load() }
    }

    private func summarySection(_ summary: GamificationSummary) -> some View {
        Section("Your Stats") {
            LabeledContent("Total Points") {
                Text("\(summary.totalPoints)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.orange)
            }
            LabeledContent("Current Streak") {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(summary.currentStreak)")
                        .font(.title3.weight(.semibold))
                }
            }
            LabeledContent("Total Events", value: "\(summary.eventCount)")
        }
    }

    private func leaderboardSection(_ board: LeaderboardResponse) -> some View {
        Section("Leaderboard") {
            ForEach(Array(board.leaderboard.enumerated()), id: \.element.id) { index, entry in
                HStack {
                    Text(medalEmoji(for: index))
                        .font(.title3)
                    Text(displayName(for: entry.userId))
                        .font(.body)
                    Spacer()
                    Text("\(entry.totalPoints) pts")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var recentEventsSection: some View {
        Section("Recent Activity") {
            ForEach(viewModel.events) { event in
                HStack {
                    VStack(alignment: .leading) {
                        Text(event.eventType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.body)
                        Text(event.at.relativeDisplay)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if event.deltaPoints != 0 {
                        Text(event.deltaPoints > 0 ? "+\(event.deltaPoints)" : "\(event.deltaPoints)")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(event.deltaPoints > 0 ? .green : .red)
                    }
                }
            }
        }
    }

    private var nudgesSection: some View {
        Section("Tips") {
            ForEach(viewModel.nudges, id: \.message) { nudge in
                HStack(spacing: 10) {
                    Text(nudge.icon)
                        .font(.title2)
                    Text(nudge.message)
                        .font(.subheadline)
                }
            }
        }
    }

    private var badgesSection: some View {
        Section("Badges") {
            ForEach(viewModel.badges) { badge in
                HStack {
                    Text(badgeEmoji(for: badge.badgeType))
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text(badgeLabel(for: badge.badgeType))
                            .font(.body.weight(.semibold))
                        Text(badge.earnedAt.relativeDisplay)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private func badgeEmoji(for type: String) -> String {
        switch type {
        case "first_completion": return "🎯"
        case "streak_3": return "🔥"
        case "streak_7": return "⚡"
        case "streak_30": return "💎"
        case "perfect_week": return "🌟"
        case "century_club": return "💯"
        default: return "🏅"
        }
    }

    private func badgeLabel(for type: String) -> String {
        switch type {
        case "first_completion": return "First Completion"
        case "streak_3": return "3-Day Streak"
        case "streak_7": return "7-Day Streak"
        case "streak_30": return "30-Day Streak"
        case "perfect_week": return "Perfect Week"
        case "century_club": return "Century Club"
        default: return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func displayName(for userId: UUID) -> String {
        members.first { $0.userId == userId }?.displayName ?? "Unknown"
    }

    private func medalEmoji(for index: Int) -> String {
        switch index {
        case 0: "🥇"
        case 1: "🥈"
        case 2: "🥉"
        default: "\(index + 1)."
        }
    }
}
