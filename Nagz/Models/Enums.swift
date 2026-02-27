import Foundation

enum FamilyRole: String, Codable, CaseIterable {
    case guardian
    case participant
    case child

    /// Can create nags for others
    var canCreateNags: Bool {
        self != .child
    }

    /// Can view all family nags (not just own)
    var canViewAllNags: Bool {
        self == .guardian
    }

    /// Has admin powers (manage members, preferences, consents, incentives)
    var isAdmin: Bool {
        self == .guardian
    }
}

enum MembershipStatus: String, Codable {
    case active
    case removed
}

enum NagCategory: String, Codable, CaseIterable {
    case chores
    case meds
    case homework
    case appointments
    case other

    var displayName: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .chores: "house.fill"
        case .meds: "pill.fill"
        case .homework: "book.fill"
        case .appointments: "calendar"
        case .other: "ellipsis.circle.fill"
        }
    }
}

enum DoneDefinition: String, Codable, CaseIterable {
    case ackOnly = "ack_only"
    case binaryCheck = "binary_check"
    case binaryWithNote = "binary_with_note"

    var displayName: String {
        switch self {
        case .ackOnly: "Acknowledge"
        case .binaryCheck: "Check Off"
        case .binaryWithNote: "Check Off + Note"
        }
    }
}

enum NagStatus: String, Codable {
    case open
    case completed
    case missed
    case cancelledRelationshipChange = "cancelled_relationship_change"
}

enum EscalationPhase: String, Codable, Comparable {
    case phase0Initial = "phase_0_initial"
    case phase1DueSoon = "phase_1_due_soon"
    case phase2OverdueSoft = "phase_2_overdue_soft"
    case phase3OverdueBoundedPushback = "phase_3_overdue_bounded_pushback"
    case phase4GuardianReview = "phase_4_guardian_review"

    var displayName: String {
        switch self {
        case .phase0Initial: "Created"
        case .phase1DueSoon: "Due Soon"
        case .phase2OverdueSoft: "Overdue"
        case .phase3OverdueBoundedPushback: "Escalated"
        case .phase4GuardianReview: "Guardian Review"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .phase0Initial: 0
        case .phase1DueSoon: 1
        case .phase2OverdueSoft: 2
        case .phase3OverdueBoundedPushback: 3
        case .phase4GuardianReview: 4
        }
    }

    static func < (lhs: EscalationPhase, rhs: EscalationPhase) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

enum StrategyTemplate: String, Codable {
    case friendlyReminder = "friendly_reminder"
}

enum Recurrence: String, Codable, CaseIterable {
    case every5Minutes = "every_5_minutes"
    case every15Minutes = "every_15_minutes"
    case every30Minutes = "every_30_minutes"
    case hourly
    case daily
    case weekly
    case monthly

    var displayName: String {
        switch self {
        case .every5Minutes: "Every 5 min"
        case .every15Minutes: "Every 15 min"
        case .every30Minutes: "Every 30 min"
        case .hourly: "Hourly"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }

    var iconName: String {
        "repeat"
    }

    /// Suggested initial due interval for this recurrence.
    var timeInterval: TimeInterval {
        switch self {
        case .every5Minutes: 5 * 60
        case .every15Minutes: 15 * 60
        case .every30Minutes: 30 * 60
        case .hourly: 60 * 60
        case .daily: 24 * 60 * 60
        case .weekly: 7 * 24 * 60 * 60
        case .monthly: 30 * 24 * 60 * 60
        }
    }
}

enum ConnectionStatus: String, Codable {
    case pending
    case active
    case declined
    case revoked
}

enum DevicePlatform: String, Codable {
    case ios
    case ipados
    case macos
}

enum ConsentType: String, Codable, CaseIterable {
    case childAccountCreation = "child_account_creation"
    case smsOptIn = "sms_opt_in"
    case aiMediation = "ai_mediation"
    case gamificationParticipation = "gamification_participation"

    var displayName: String {
        switch self {
        case .childAccountCreation: "Child Account Creation"
        case .smsOptIn: "SMS Notifications"
        case .aiMediation: "AI Mediation"
        case .gamificationParticipation: "Gamification"
        }
    }

    var description: String {
        switch self {
        case .childAccountCreation: "Allow creating child accounts in this family"
        case .smsOptIn: "Receive SMS notifications for nag updates"
        case .aiMediation: "Allow AI to mediate nag excuses and pushback"
        case .gamificationParticipation: "Enable points, streaks, and leaderboards"
        }
    }
}

enum IncentiveApprovalMode: String, Codable, CaseIterable {
    case auto
    case guardianConfirmed = "guardian_confirmed"

    var displayName: String {
        switch self {
        case .auto: "Automatic"
        case .guardianConfirmed: "Guardian Confirmed"
        }
    }
}
