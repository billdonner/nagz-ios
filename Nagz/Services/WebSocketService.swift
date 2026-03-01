import Foundation

/// Real-time event types received from the server via WebSocket.
enum NagEventType: String, Sendable {
    case nagCreated = "nag_created"
    case nagUpdated = "nag_updated"
    case nagStatusChanged = "nag_status_changed"
    case excuseSubmitted = "excuse_submitted"
    case memberAdded = "member_added"
    case memberRemoved = "member_removed"
    case connectionInvited = "connection_invited"
    case connectionAccepted = "connection_accepted"
    case ping
    case pong
}

/// A real-time event received over WebSocket.
struct NagEvent: Sendable {
    let type: NagEventType
    let familyId: String?
    let actorId: String?
    /// Raw JSON data payload as a string (parse as needed).
    let rawData: String
    let timestamp: String?

    init(type: NagEventType, familyId: String? = nil, actorId: String? = nil, rawData: String = "{}", timestamp: String? = nil) {
        self.type = type
        self.familyId = familyId
        self.actorId = actorId
        self.rawData = rawData
        self.timestamp = timestamp
    }
}

/// Actor-based WebSocket client for real-time family event streaming.
///
/// Connects to `wss://server/api/v1/ws?token=...&family_id=...`,
/// decodes JSON events, and exposes them via `AsyncStream<NagEvent>`.
/// Auto-reconnects with exponential backoff on disconnect.
actor WebSocketService {
    private let keychainService: KeychainService
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var familyId: UUID?
    private var isConnected = false
    private var reconnectDelay: TimeInterval = 1
    private var shouldReconnect = false

    private var continuation: AsyncStream<NagEvent>.Continuation?
    private(set) var eventStream: AsyncStream<NagEvent>?

    private static let maxReconnectDelay: TimeInterval = 30
    private static let pingInterval: TimeInterval = 25

    init(keychainService: KeychainService) {
        self.keychainService = keychainService
    }

    /// Connect to the WebSocket for a family. Returns an AsyncStream of events.
    func connect(familyId: UUID) -> AsyncStream<NagEvent> {
        self.familyId = familyId
        self.shouldReconnect = true
        self.reconnectDelay = 1

        let stream = AsyncStream<NagEvent> { continuation in
            self.continuation = continuation
        }
        self.eventStream = stream

        Task { await openConnection() }

        return stream
    }

    /// Disconnect from the WebSocket and stop receiving events.
    func disconnect() {
        shouldReconnect = false
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        continuation?.finish()
        continuation = nil
        eventStream = nil
    }

    // MARK: - Private

    private func openConnection() async {
        guard let familyId, shouldReconnect else { return }

        let token = await keychainService.accessToken
        guard let token else {
            DebugLogger.shared.log("WebSocket: no access token available", level: .warning)
            return
        }

        let baseURL = AppEnvironment.current.baseURL
        // Convert https:// to wss:// for WebSocket
        var urlString = baseURL.absoluteString
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        // Remove trailing /api/v1 if present (we'll add our own path)
        if urlString.hasSuffix("/api/v1") {
            urlString = String(urlString.dropLast("/api/v1".count))
        }

        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        urlString += "/api/v1/ws?token=\(encodedToken)&family_id=\(familyId.uuidString.lowercased())"

        guard let url = URL(string: urlString) else {
            DebugLogger.shared.log("WebSocket: invalid URL", level: .error)
            return
        }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        isConnected = true

        DebugLogger.shared.log("WebSocket: connecting to \(url.host ?? "?")")

        startReceiving()
        startPinging()
    }

    private func startReceiving() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard let task = await self.webSocketTask else { return }
                do {
                    let message = try await task.receive()
                    await self.resetReconnectDelay()
                    switch message {
                    case .string(let text):
                        await self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            await self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    DebugLogger.shared.log("WebSocket: receive error — \(error.localizedDescription)", level: .warning)
                    await self.handleDisconnect()
                    return
                }
            }
        }
    }

    private func startPinging() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pingInterval))
                guard let self else { return }
                guard !Task.isCancelled else { return }
                guard let task = await self.webSocketTask else { return }
                do {
                    try await task.send(.string("ping"))
                } catch {
                    DebugLogger.shared.log("WebSocket: ping failed", level: .warning)
                    await self.handleDisconnect()
                    return
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        guard let eventName = json["event"] as? String else { return }

        // Handle ping/pong internally
        if eventName == "ping" || eventName == "pong" {
            return
        }

        guard let eventType = NagEventType(rawValue: eventName) else {
            DebugLogger.shared.log("WebSocket: unknown event type '\(eventName)'", level: .warning)
            return
        }

        // Serialize the data portion back to a JSON string for Sendable safety
        var rawDataString = "{}"
        if let dataObj = json["data"] {
            if let dataBytes = try? JSONSerialization.data(withJSONObject: dataObj) {
                rawDataString = String(data: dataBytes, encoding: .utf8) ?? "{}"
            }
        }

        let event = NagEvent(
            type: eventType,
            familyId: json["family_id"] as? String,
            actorId: json["actor_id"] as? String,
            rawData: rawDataString,
            timestamp: json["ts"] as? String
        )

        continuation?.yield(event)
    }

    private func resetReconnectDelay() {
        reconnectDelay = 1
    }

    private func handleDisconnect() async {
        isConnected = false
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        guard shouldReconnect else { return }

        DebugLogger.shared.log("WebSocket: reconnecting in \(reconnectDelay)s")
        try? await Task.sleep(for: .seconds(reconnectDelay))
        reconnectDelay = min(reconnectDelay * 2, Self.maxReconnectDelay)

        guard shouldReconnect else { return }
        await openConnection()
    }
}
