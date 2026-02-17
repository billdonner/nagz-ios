import SwiftUI

struct GamificationView: View {
    @State private var viewModel: GamificationViewModel
    let members: [MemberDetail]

    init(apiClient: APIClient, familyId: UUID, userId: UUID, members: [MemberDetail]) {
        _viewModel = State(initialValue: GamificationViewModel(apiClient: apiClient, familyId: familyId, userId: userId))
        self.members = members
    }

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.summary == nil {
                ProgressView().frame(maxWidth: .infinity)
            } else if let error = viewModel.errorMessage, viewModel.summary == nil {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                if let summary = viewModel.summary {
                    summarySection(summary)
                }

                if let board = viewModel.leaderboard, !board.leaderboard.isEmpty {
                    leaderboardSection(board)
                }

                if !viewModel.events.isEmpty {
                    recentEventsSection
                }
            }
        }
        .navigationTitle("Gamification")
        .refreshable { await viewModel.load() }
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
