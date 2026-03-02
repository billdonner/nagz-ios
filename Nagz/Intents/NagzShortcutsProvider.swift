import AppIntents

struct NagzShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNagIntent(),
            phrases: [
                "Create a nag in \(.applicationName)",
                "Add a nag in \(.applicationName)",
                "Nag someone in \(.applicationName)",
                "Add a task in \(.applicationName)",
                "Nag me to in \(.applicationName)",
                "Create a reminder in \(.applicationName)"
            ],
            shortTitle: "Create Nag",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: CompleteNagIntent(),
            phrases: [
                "Complete a nag in \(.applicationName)",
                "Mark nag done in \(.applicationName)",
                "I finished in \(.applicationName)",
                "Mark done in \(.applicationName)",
                "Complete a task in \(.applicationName)"
            ],
            shortTitle: "Complete Nag",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: ListNagsIntent(),
            phrases: [
                "Show my nags in \(.applicationName)",
                "List nags in \(.applicationName)",
                "What are my nags in \(.applicationName)",
                "What's overdue in \(.applicationName)",
                "Show my tasks in \(.applicationName)"
            ],
            shortTitle: "List Nags",
            systemImageName: "list.bullet"
        )

        AppShortcut(
            intent: CheckOverdueIntent(),
            phrases: [
                "Check overdue nags in \(.applicationName)",
                "Any overdue nags in \(.applicationName)",
                "What's late in \(.applicationName)"
            ],
            shortTitle: "Check Overdue",
            systemImageName: "exclamationmark.triangle"
        )

        AppShortcut(
            intent: SnoozeNagIntent(),
            phrases: [
                "Snooze a nag in \(.applicationName)",
                "Postpone a nag in \(.applicationName)",
                "Delay a task in \(.applicationName)"
            ],
            shortTitle: "Snooze Nag",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: FamilyStatusIntent(),
            phrases: [
                "Family status in \(.applicationName)",
                "How is my family doing in \(.applicationName)",
                "Family update in \(.applicationName)"
            ],
            shortTitle: "Family Status",
            systemImageName: "chart.bar"
        )
    }
}
