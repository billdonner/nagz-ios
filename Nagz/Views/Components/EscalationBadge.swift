import SwiftUI

struct EscalationBadge: View {
    let phase: EscalationPhase

    var body: some View {
        Text(phase.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch phase {
        case .phase0Initial: .gray.opacity(0.15)
        case .phase1DueSoon: .yellow.opacity(0.15)
        case .phase2OverdueSoft: .orange.opacity(0.15)
        case .phase3OverdueBoundedPushback: .red.opacity(0.15)
        case .phase4GuardianReview: .purple.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch phase {
        case .phase0Initial: .gray
        case .phase1DueSoon: .yellow
        case .phase2OverdueSoft: .orange
        case .phase3OverdueBoundedPushback: .red
        case .phase4GuardianReview: .purple
        }
    }
}
