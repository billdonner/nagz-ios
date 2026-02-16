import Foundation

struct DeviceTokenRegister: Encodable {
    let platform: DevicePlatform
    let token: String
}

struct DeviceTokenResponse: Decodable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let platform: DevicePlatform
    let token: String
    let createdAt: Date
    let lastUsedAt: Date?
}
