import Foundation

struct EscalationResponse: Decodable, Sendable {
    let nagId: UUID
    let currentPhase: EscalationPhase
    let dueAt: Date
    let computedAt: Date
}
