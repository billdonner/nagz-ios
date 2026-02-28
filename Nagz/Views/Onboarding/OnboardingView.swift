import SwiftUI

struct OnboardingView: View {
    let isRerun: Bool
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let pages = OnboardingPage.allPages

    init(isRerun: Bool = false) {
        self.isRerun = isRerun
    }

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                OnboardingPageView(
                    page: page,
                    isLastPage: index == pages.count - 1,
                    buttonTitle: isRerun ? "Done" : "Get Started",
                    onGetStarted: {
                        if isRerun {
                            dismiss()
                        } else {
                            hasSeenOnboarding = true
                        }
                    }
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
            subtitle: "Set up your family, invite members, and assign roles. See the weekly AI digest right on your Family page, with member avatars and easy invite sharing.",
            supportingIcons: [
                ("person.badge.shield.checkmark", "Guardian"),
                ("sparkles", "Digest"),
                ("square.and.arrow.up", "Invite"),
            ]
        ),
        OnboardingPage(
            symbol: "person.2.fill",
            color: .teal,
            title: "Connect & Nag Anyone",
            subtitle: "Use the People tab to invite friends and family by email. Tap a connection to create a nag instantly, and track per-connection stats.",
            supportingIcons: [
                ("person.badge.plus", "Invite"),
                ("bell.badge.fill", "Nag"),
                ("chart.bar.fill", "Stats"),
            ]
        ),
        OnboardingPage(
            symbol: "sparkles",
            color: .indigo,
            title: "AI-Powered Insights",
            subtitle: "Get rich AI analysis with urgency scoring, coaching tips, and completion predictions. Choose from celebrity AI personalities for a unique experience.",
            supportingIcons: [
                ("chart.line.uptrend.xyaxis", "Analysis"),
                ("theatermasks.fill", "Personality"),
                ("lightbulb.fill", "Coaching"),
            ]
        ),
        OnboardingPage(
            symbol: "bell.and.waves.left.and.right",
            color: .green,
            title: "Stay in the Loop",
            subtitle: "Get push notifications when nags are due, completed, or escalated. Build streaks, earn badges, and climb the family leaderboard.",
            supportingIcons: [
                ("bell.fill", "Notify"),
                ("flame.fill", "Streaks"),
                ("medal.fill", "Badges"),
            ]
        ),
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isLastPage: Bool
    let buttonTitle: String
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
                    Text(buttonTitle)
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
