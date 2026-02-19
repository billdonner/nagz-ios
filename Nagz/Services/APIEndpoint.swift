import Foundation

private nonisolated(unsafe) let sharedISO8601Formatter = ISO8601DateFormatter()

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

    /// Key for in-memory caching, combining path and query parameters.
    var cacheKey: String {
        let query = queryItems.map { "\($0.name)=\($0.value ?? "")" }.sorted().joined(separator: "&")
        return query.isEmpty ? path : "\(path)?\(query)"
    }

    // MARK: - Version

    static func getVersion() -> APIEndpoint {
        APIEndpoint(path: "/version", requiresAuth: false)
    }

    // MARK: - Auth

    static func signup(email: String, password: String, displayName: String?, dateOfBirth: Date? = nil) -> APIEndpoint {
        APIEndpoint(
            path: "/auth/signup",
            method: .post,
            body: SignupRequest(email: email, password: password, displayName: displayName, dateOfBirth: dateOfBirth),
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

    static func updateNag(nagId: UUID, update: NagUpdate) -> APIEndpoint {
        APIEndpoint(
            path: "/nags/\(nagId)",
            method: .patch,
            body: update
        )
    }

    // MARK: - Excuses

    static func listExcuses(nagId: UUID, limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        APIEndpoint(
            path: "/nags/\(nagId)/excuses",
            queryItems: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    static func submitExcuse(nagId: UUID, text: String, category: String? = nil) -> APIEndpoint {
        APIEndpoint(
            path: "/nags/\(nagId)/excuses",
            method: .post,
            body: ExcuseCreate(text: text, category: category)
        )
    }

    // MARK: - Escalation

    static func getEscalation(nagId: UUID) -> APIEndpoint {
        APIEndpoint(path: "/nags/\(nagId)/escalation")
    }

    static func recomputeEscalation(nagId: UUID) -> APIEndpoint {
        APIEndpoint(path: "/nags/\(nagId)/escalation/recompute", method: .post)
    }

    // MARK: - Family Members

    static func addMember(familyId: UUID, userId: UUID, role: FamilyRole) -> APIEndpoint {
        APIEndpoint(
            path: "/families/\(familyId)/members",
            method: .post,
            body: MemberAdd(userId: userId, role: role)
        )
    }

    static func createMember(familyId: UUID, displayName: String, role: FamilyRole) -> APIEndpoint {
        APIEndpoint(
            path: "/families/\(familyId)/members/create",
            method: .post,
            body: MemberCreateAndAdd(displayName: displayName, role: role)
        )
    }

    static func removeMember(familyId: UUID, userId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/families/\(familyId)/members/\(userId)",
            method: .delete
        )
    }

    // MARK: - Preferences

    static func getPreferences(familyId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/preferences",
            queryItems: [URLQueryItem(name: "family_id", value: familyId.uuidString)]
        )
    }

    static func updatePreferences(familyId: UUID, prefs: [String: AnyCodableValue]) -> APIEndpoint {
        APIEndpoint(
            path: "/preferences",
            method: .patch,
            body: PreferenceUpdate(prefsJson: prefs),
            queryItems: [URLQueryItem(name: "family_id", value: familyId.uuidString)]
        )
    }

    // MARK: - Consents

    static func listConsents(familyId: UUID, limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        APIEndpoint(
            path: "/consents",
            queryItems: [
                URLQueryItem(name: "family_id", value: familyId.uuidString),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    static func grantConsent(familyId: UUID?, consentType: ConsentType) -> APIEndpoint {
        APIEndpoint(
            path: "/consents",
            method: .post,
            body: ConsentCreate(familyId: familyId, consentType: consentType)
        )
    }

    static func revokeConsent(consentId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/consents/\(consentId)",
            method: .patch,
            body: ConsentUpdate(revoked: true)
        )
    }

    // MARK: - Gamification

    static func gamificationSummary(familyId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/gamification/summary",
            queryItems: [URLQueryItem(name: "family_id", value: familyId.uuidString)]
        )
    }

    static func gamificationLeaderboard(familyId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/gamification/leaderboard",
            queryItems: [URLQueryItem(name: "family_id", value: familyId.uuidString)]
        )
    }

    static func gamificationBadges(userId: UUID, familyId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/gamification/badges",
            queryItems: [
                URLQueryItem(name: "user_id", value: userId.uuidString),
                URLQueryItem(name: "family_id", value: familyId.uuidString),
            ]
        )
    }

    static func gamificationEvents(userId: UUID, familyId: UUID? = nil, limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        var items = [
            URLQueryItem(name: "user_id", value: userId.uuidString),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        if let familyId {
            items.append(URLQueryItem(name: "family_id", value: familyId.uuidString))
        }
        return APIEndpoint(path: "/gamification/events", queryItems: items)
    }

    // MARK: - Incentive Rules

    static func listIncentiveRules(familyId: UUID, limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        APIEndpoint(
            path: "/incentive-rules",
            queryItems: [
                URLQueryItem(name: "family_id", value: familyId.uuidString),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    static func createIncentiveRule(_ rule: IncentiveRuleCreate) -> APIEndpoint {
        APIEndpoint(path: "/incentive-rules", method: .post, body: rule)
    }

    static func updateIncentiveRule(ruleId: UUID, update: IncentiveRuleUpdate) -> APIEndpoint {
        APIEndpoint(
            path: "/incentive-rules/\(ruleId)",
            method: .patch,
            body: update
        )
    }

    static func listIncentiveEvents(nagId: UUID, limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        APIEndpoint(
            path: "/incentive-events",
            queryItems: [
                URLQueryItem(name: "nag_id", value: nagId.uuidString),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    // MARK: - Reports

    static func weeklyReport(familyId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/reports/family/weekly",
            queryItems: [URLQueryItem(name: "family_id", value: familyId.uuidString)]
        )
    }

    static func familyMetrics(familyId: UUID, from: Date? = nil, to: Date? = nil) -> APIEndpoint {
        var items = [URLQueryItem(name: "family_id", value: familyId.uuidString)]
        if let from {
            items.append(URLQueryItem(name: "from_date", value: sharedISO8601Formatter.string(from: from)))
        }
        if let to {
            items.append(URLQueryItem(name: "to_date", value: sharedISO8601Formatter.string(from: to)))
        }
        return APIEndpoint(path: "/reports/family/metrics", queryItems: items)
    }

    // MARK: - Deliveries

    static func listDeliveries(nagId: UUID, limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        APIEndpoint(
            path: "/deliveries",
            queryItems: [
                URLQueryItem(name: "nag_id", value: nagId.uuidString),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    // MARK: - Policies

    static func listPolicies(familyId: UUID, limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        APIEndpoint(
            path: "/policies",
            queryItems: [
                URLQueryItem(name: "family_id", value: familyId.uuidString),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    static func getPolicy(id: UUID) -> APIEndpoint {
        APIEndpoint(path: "/policies/\(id)")
    }

    static func updatePolicy(policyId: UUID, update: PolicyUpdate) -> APIEndpoint {
        APIEndpoint(
            path: "/policies/\(policyId)",
            method: .patch,
            body: update
        )
    }

    static func createApproval(policyId: UUID, comment: String? = nil) -> APIEndpoint {
        APIEndpoint(
            path: "/policies/\(policyId)/approvals",
            method: .post,
            body: ApprovalCreate(comment: comment)
        )
    }

    static func listApprovals(policyId: UUID, limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        APIEndpoint(
            path: "/policies/\(policyId)/approvals",
            queryItems: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    // MARK: - Safety

    static func createAbuseReport(targetId: UUID, reason: String) -> APIEndpoint {
        APIEndpoint(
            path: "/abuse-reports",
            method: .post,
            body: AbuseReportCreate(targetId: targetId, reason: reason)
        )
    }

    static func getAbuseReport(id: UUID) -> APIEndpoint {
        APIEndpoint(path: "/abuse-reports/\(id)")
    }

    static func createBlock(targetId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/blocks",
            method: .post,
            body: BlockCreateRequest(targetId: targetId)
        )
    }

    static func updateBlock(blockId: UUID, state: BlockState) -> APIEndpoint {
        APIEndpoint(
            path: "/blocks/\(blockId)",
            method: .patch,
            body: BlockUpdateRequest(state: state)
        )
    }

    static func listBlocks(limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        APIEndpoint(
            path: "/blocks",
            queryItems: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    static func suspendRelationship(relationshipId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/relationships/\(relationshipId)/suspend",
            method: .post
        )
    }

    // MARK: - Accounts

    static func deleteAccount(userId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/accounts/\(userId)",
            method: .delete
        )
    }

    static func exportAccountData() -> APIEndpoint {
        APIEndpoint(path: "/accounts/export", method: .post)
    }

    // MARK: - Legal

    static func privacyPolicy() -> APIEndpoint {
        APIEndpoint(path: "/legal/privacy-policy", requiresAuth: false)
    }

    static func termsOfService() -> APIEndpoint {
        APIEndpoint(path: "/legal/terms-of-service", requiresAuth: false)
    }

    // MARK: - Devices

    static func registerDevice(platform: DevicePlatform, token: String) -> APIEndpoint {
        APIEndpoint(
            path: "/devices",
            method: .post,
            body: DeviceTokenRegister(platform: platform, token: token)
        )
    }

    static func listDevices(limit: Int = Constants.Pagination.defaultLimit, offset: Int = 0) -> APIEndpoint {
        APIEndpoint(
            path: "/devices",
            queryItems: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    static func deleteDevice(deviceId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/devices/\(deviceId)",
            method: .delete
        )
    }

    // MARK: - AI

    static func aiSummarizeExcuse(text: String, nagId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/ai/summarize-excuse",
            method: .post,
            body: ExcuseSummaryRequest(text: text, nagId: nagId)
        )
    }

    static func aiSelectTone(nagId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/ai/select-tone",
            method: .post,
            body: ToneSelectRequest(nagId: nagId)
        )
    }

    static func aiCoaching(nagId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/ai/coaching",
            method: .post,
            body: CoachingRequest(nagId: nagId)
        )
    }

    static func aiPatterns(userId: UUID, familyId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/ai/patterns",
            queryItems: [
                URLQueryItem(name: "user_id", value: userId.uuidString),
                URLQueryItem(name: "family_id", value: familyId.uuidString),
            ]
        )
    }

    static func aiDigest(familyId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/ai/digest",
            queryItems: [URLQueryItem(name: "family_id", value: familyId.uuidString)]
        )
    }

    static func aiPredictCompletion(nagId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/ai/predict-completion",
            queryItems: [URLQueryItem(name: "nag_id", value: nagId.uuidString)]
        )
    }

    static func aiPushBack(nagId: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/ai/push-back",
            method: .post,
            body: PushBackRequest(nagId: nagId)
        )
    }

    // MARK: - Sync

    static func syncEvents(familyId: UUID, since: Date?) -> APIEndpoint {
        var items = [URLQueryItem(name: "family_id", value: familyId.uuidString)]
        if let since {
            items.append(URLQueryItem(name: "since", value: sharedISO8601Formatter.string(from: since)))
        }
        return APIEndpoint(path: "/sync/events", queryItems: items)
    }
}
