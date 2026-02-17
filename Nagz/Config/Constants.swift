import Foundation

enum Constants {
    enum Version {
        /// The API version this client was built against
        static let clientAPIVersion = "1.0.0"
    }

    enum Keychain {
        static let serviceName = "com.nagz.app"
        static let accessTokenKey = "access_token"
        static let refreshTokenKey = "refresh_token"
    }

    enum Pagination {
        static let defaultLimit = 50
        static let maxLimit = 200
    }

    enum DateFormat {
        nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        nonisolated(unsafe) static let iso8601NoFractional: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()
    }
}
