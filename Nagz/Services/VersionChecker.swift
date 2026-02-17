import Foundation
import Observation

enum VersionStatus: Sendable {
    case unknown
    case compatible
    case updateRecommended(serverAPI: String, clientAPI: String)
    case updateRequired(minRequired: String, clientAPI: String)
    case checkFailed
}

@Observable
@MainActor
final class VersionChecker {
    /// The API version this client was built against.
    static let clientAPIVersion = "1.0.0"

    private(set) var status: VersionStatus = .unknown
    private(set) var serverInfo: VersionResponse?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func check() async {
        do {
            let response: VersionResponse = try await apiClient.request(.getVersion())
            serverInfo = response
            status = Self.evaluate(
                serverAPI: response.apiVersion,
                minClient: response.minClientVersion
            )
        } catch {
            // Don't block the app if the version check fails (e.g. old server)
            status = .checkFailed
        }
    }

    static func evaluate(serverAPI: String, minClient: String) -> VersionStatus {
        let client = parseVersion(clientAPIVersion)
        let server = parseVersion(serverAPI)
        let minimum = parseVersion(minClient)

        // Client version is below the server's minimum → must update
        if client < minimum {
            return .updateRequired(minRequired: minClient, clientAPI: clientAPIVersion)
        }

        // Client's major version is behind the server → recommend update
        if client.major < server.major {
            return .updateRecommended(serverAPI: serverAPI, clientAPI: clientAPIVersion)
        }

        return .compatible
    }

    // MARK: - Semver parsing

    private struct SemVer: Comparable {
        let major: Int
        let minor: Int
        let patch: Int

        static func < (lhs: SemVer, rhs: SemVer) -> Bool {
            if lhs.major != rhs.major { return lhs.major < rhs.major }
            if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
            return lhs.patch < rhs.patch
        }
    }

    private static func parseVersion(_ string: String) -> SemVer {
        let parts = string.split(separator: ".").compactMap { Int($0) }
        return SemVer(
            major: parts.count > 0 ? parts[0] : 0,
            minor: parts.count > 1 ? parts[1] : 0,
            patch: parts.count > 2 ? parts[2] : 0
        )
    }
}
