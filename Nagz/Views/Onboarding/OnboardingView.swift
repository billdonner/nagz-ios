import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let pages = OnboardingPage.allPages

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                OnboardingPageView(
                    page: page,
                    isLastPage: index == pages.count - 1,
                    onGetStarted: { hasSeenOnboarding = true }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

struct OnboardingPage {
    let symbol: String
    let color: Color
    let title: String
    let subtitle: String
    let supportingIcons: [(symbol: String, label: String)]

    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "bell.badge.fill",
            color: .blue,
            title: "Never Forget Again",
            subtitle: "Create reminders for your family — meds, chores, homework, appointments. Nagz keeps everyone on track.",
            supportingIcons: [
                ("house.fill", "Chores"),
                ("pill.fill", "Meds"),
                ("book.fill", "School"),
                ("calendar", "Appts"),
            ]
        ),
        OnboardingPage(
            symbol: "person.3.fill",
            color: .purple,
            title: "Your Family Hub",
            subtitle: "Set up your family, invite members, and assign roles. Guardians oversee, participants pitch in, kids stay accountable.",
            supportingIcons: [
                ("person.badge.shield.checkmark", "Guardian"),
                ("person.badge.clock", "Member"),
                ("person.fill", "Child"),
            ]
        ),
        OnboardingPage(
            symbol: "arrow.up.arrow.down.circle.fill",
            color: .orange,
            title: "Smart Escalation",
            subtitle: "Reminders start gentle and get louder. From a friendly nudge to guardian review — nothing slips through the cracks.",
            supportingIcons: [
                ("circle.fill", "Created"),
                ("exclamationmark.circle.fill", "Overdue"),
                ("exclamationmark.triangle.fill", "Escalated"),
            ]
        ),
        OnboardingPage(
            symbol: "flame.fill",
            color: .orange,
            title: "Earn Points & Streaks",
            subtitle: "Turn tasks into a game. Complete nags to earn points, build streaks, climb the family leaderboard, and unlock badges.",
            supportingIcons: [
                ("star.fill", "Points"),
                ("trophy.fill", "Leaderboard"),
                ("medal.fill", "Badges"),
            ]
        ),
        OnboardingPage(
            symbol: "bell.and.waves.left.and.right",
            color: .green,
            title: "Stay in the Loop",
            subtitle: "Get push notifications when nags are due, completed, or need attention. Your family, always connected.",
            supportingIcons: [
                ("checkmark.circle.fill", "Done"),
                ("clock.badge.xmark", "Snooze"),
                ("text.bubble", "Excuse"),
            ]
        ),
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isLastPage: Bool
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.symbol)
                .font(.system(size: 72))
                .foregroundStyle(page.color)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title).bold()

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 24) {
                ForEach(page.supportingIcons, id: \.symbol) { icon in
                    VStack(spacing: 4) {
                        Image(systemName: icon.symbol)
                            .font(.title3)
                        Text(icon.label)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isLastPage {
                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(page.color.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            } else {
                Color.clear.frame(height: 70)
            }
        }
    }
}
