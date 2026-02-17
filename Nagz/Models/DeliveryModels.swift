import Foundation

enum DeliveryChannel: String, Codable, Sendable {
    case push
    case sms
}

enum DeliveryStatus: String, Codable, Sendable {
    case pending
    case sent
    case delivered
    case failed

    var displayName: String {
        rawValue.capitalized
    }
}

struct DeliveryResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let nagEventId: UUID
    let channel: DeliveryChannel
    let status: DeliveryStatus
    let providerRef: String?
}
