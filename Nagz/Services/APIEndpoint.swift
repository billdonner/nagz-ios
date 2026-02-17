import Foundation

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: Encodable?
    let queryItems: [URLQueryItem]
    let requiresAuth: Bool

    init(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        queryItems: [URLQueryItem] = [],
        requiresAuth: Bool = true
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
        self.requiresAuth = requiresAuth
    }

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    // MARK: - Auth

    static func signup(email: String, password: String, displayName: String?) -> APIEndpoint {
        APIEndpoint(
            path: "/auth/signup",
            method: .post,
            body: SignupRequest(email: email, password: password, displayName: displayName),
            requiresAuth: false
        )
    }

    static func login(email: String, password: String) -> APIEndpoint {
        APIEndpoint(
            path: "/auth/login",
            method: .post,
            body: LoginRequest(email: email, password: password),
            requiresAuth: false
        )
    }

    static func refresh(refreshToken: String) -> APIEndpoint {
        APIEndpoint(
            path: "/auth/refresh",
            method: .post,
            body: RefreshRequest(refreshToken: refreshToken),
            requiresAuth: false
        )
    }

    static func logout() -> APIEndpoint {
        APIEndpoint(path: "/auth/logout", method: .post)
    }

    // MARK: - Families

    static func createFamily(name: String) -> APIEndpoint {
        APIEndpoint(
            path: "/families",
            method: .post,
            body: FamilyCreate(name: name)
        )
    }

    static func getFamily(id: UUID) -> APIEndpoint {
        APIEndpoint(path: "/families/\(id)")
    }

    static func joinFamily(inviteCode: String) -> APIEndpoint {
        APIEndpoint(
            path: "/families/join",
            method: .post,
            body: JoinRequest(inviteCode: inviteCode)
        )
    }

    static func listMembers(familyId: UUID, limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        APIEndpoint(
            path: "/families/\(familyId)/members",
            queryItems: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    // MARK: - Nags

    static func createNag(_ nag: NagCreate) -> APIEndpoint {
        APIEndpoint(path: "/nags", method: .post, body: nag)
    }

    static func listNags(familyId: UUID, status: NagStatus? = nil, limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        var items = [
            URLQueryItem(name: "family_id", value: familyId.uuidString),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        if let status {
            items.append(URLQueryItem(name: "state", value: status.rawValue))
        }
        return APIEndpoint(path: "/nags", queryItems: items)
    }

    static func getNag(id: UUID) -> APIEndpoint {
        APIEndpoint(path: "/nags/\(id)")
    }

    static func updateNagStatus(nagId: UUID, status: NagStatus, note: String? = nil) -> APIEndpoint {
        APIEndpoint(
            path: "/nags/\(nagId)/status",
            method: .post,
            body: NagStatusUpdate(status: status, note: note)
        )
    }

    // MARK: - Escalation

    static func getEscalation(nagId: UUID) -> APIEndpoint {
        APIEndpoint(path: "/nags/\(nagId)/escalation")
    }

    // MARK: - Devices

    static func registerDevice(platform: DevicePlatform, token: String) -> APIEndpoint {
        APIEndpoint(
            path: "/devices",
            method: .post,
            body: DeviceTokenRegister(platform: platform, token: token)
        )
    }
}
