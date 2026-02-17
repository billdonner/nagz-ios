import Foundation

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let keychainService: KeychainService
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var onUnauthorized: (@Sendable () -> Void)?

    init(baseURL: URL = AppEnvironment.current.baseURL, keychainService: KeychainService) {
        self.baseURL = baseURL
        self.keychainService = keychainService

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = Constants.DateFormat.iso8601.date(from: dateString) {
                return date
            }
            if let date = Constants.DateFormat.iso8601NoFractional.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }

        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Constants.DateFormat.iso8601.string(from: date))
        }
    }

    func setOnUnauthorized(_ handler: @escaping @Sendable () -> Void) {
        self.onUnauthorized = handler
    }

    // MARK: - Public API

    @discardableResult
    func request<T: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> T {
        try await performRequest(endpoint, isRetry: false)
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {
        let _: EmptyResponse = try await performRequest(endpoint, isRetry: false)
    }

    // MARK: - Private

    private func performRequest<T: Decodable>(_ endpoint: APIEndpoint, isRetry: Bool) async throws -> T {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)!
        if !endpoint.queryItems.isEmpty {
            urlComponents.queryItems = endpoint.queryItems
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if endpoint.requiresAuth {
            if let token = await keychainService.accessToken {
                urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body = endpoint.body {
            urlRequest.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(0, "Invalid response")
        }

        // Handle 204 No Content
        if httpResponse.statusCode == 204 {
            if let empty = EmptyResponse() as? T {
                return empty
            }
        }

        // Handle 401 with token refresh
        if httpResponse.statusCode == 401 && !isRetry && endpoint.requiresAuth {
            if let refreshed = try? await refreshTokens() {
                if refreshed {
                    return try await performRequest(endpoint, isRetry: true)
                }
            }
            onUnauthorized?()
            throw APIError.unauthorized
        }

        // Handle error responses
        if httpResponse.statusCode >= 400 {
            throw parseError(data: data, statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func refreshTokens() async throws -> Bool {
        guard let refreshToken = await keychainService.refreshToken else {
            return false
        }

        let endpoint = APIEndpoint.refresh(refreshToken: refreshToken)
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)!
        if !endpoint.queryItems.isEmpty {
            urlComponents.queryItems = endpoint.queryItems
        }

        guard let url = urlComponents.url else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            try? await keychainService.clearTokens()
            return false
        }

        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        try await keychainService.saveTokens(
            access: authResponse.accessToken,
            refresh: authResponse.refreshToken
        )
        return true
    }

    private func parseError(data: Data, statusCode: Int) -> APIError {
        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            let msg = envelope.error.message
            switch statusCode {
            case 401: return .unauthorized
            case 403: return .forbidden
            case 404: return .notFound
            case 422: return .validationError(msg)
            case 429: return .rateLimited
            case 500...599: return .serverError(msg)
            default: return .unknown(statusCode, msg)
            }
        }
        return .unknown(statusCode, "Unknown error")
    }
}

// MARK: - Helpers

private struct EmptyResponse: Decodable {
    init() {}
}

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        _encode = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
