import Foundation

struct PreferenceResponse: Decodable, Sendable {
    let userId: UUID
    let familyId: UUID
    let schemaVersion: Int
    let prefsJson: [String: AnyCodableValue]
    let etag: String
    let updatedAt: Date
}

struct PreferenceUpdate: Encodable {
    let prefsJson: [String: AnyCodableValue]
}

/// A type-erased Codable value for handling arbitrary JSON in preferences.
enum AnyCodableValue: Codable, Sendable, Equatable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
}
