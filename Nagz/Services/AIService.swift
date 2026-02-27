import Foundation

/// Protocol for AI operations — implemented by both ServerAIService and NagzAIAdapter.
protocol AIService: Sendable {
    func summarizeExcuse(_ text: String, nagId: UUID) async throws -> ExcuseSummaryResponse
    func selectTone(nagId: UUID) async throws -> ToneSelectResponse
    func coaching(nagId: UUID) async throws -> CoachingResponse
    func patterns(userId: UUID, familyId: UUID) async throws -> PatternsResponse
    func digest(familyId: UUID) async throws -> DigestResponse
    func predictCompletion(nagId: UUID) async throws -> PredictCompletionResponse
    func pushBack(nagId: UUID) async throws -> PushBackResponse
}

/// Server-backed AI implementation — calls /api/v1/ai/* endpoints.
actor ServerAIService: AIService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func summarizeExcuse(_ text: String, nagId: UUID) async throws -> ExcuseSummaryResponse {
        try await apiClient.request(.aiSummarizeExcuse(text: text, nagId: nagId))
    }

    func selectTone(nagId: UUID) async throws -> ToneSelectResponse {
        try await apiClient.request(.aiSelectTone(nagId: nagId))
    }

    func coaching(nagId: UUID) async throws -> CoachingResponse {
        try await apiClient.request(.aiCoaching(nagId: nagId))
    }

    func patterns(userId: UUID, familyId: UUID) async throws -> PatternsResponse {
        try await apiClient.request(.aiPatterns(userId: userId, familyId: familyId))
    }

    func digest(familyId: UUID) async throws -> DigestResponse {
        try await apiClient.request(.aiDigest(familyId: familyId))
    }

    func predictCompletion(nagId: UUID) async throws -> PredictCompletionResponse {
        try await apiClient.request(.aiPredictCompletion(nagId: nagId))
    }

    func pushBack(nagId: UUID) async throws -> PushBackResponse {
        try await apiClient.request(.aiPushBack(nagId: nagId))
    }
}
