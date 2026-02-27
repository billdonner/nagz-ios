# Nagz iOS App

## Stack
- SwiftUI, MVVM, iOS 26+ (@Observable)
- Swift 6 strict concurrency
- Dependencies: KeychainAccess (SPM), GRDB (SPM)
- Project generated with xcodegen from `project.yml`
- Bundle ID: com.nagz.app, Version: 1.0.0

## Common Commands
- `cd ~/nagz-ios && xcodegen generate` — regenerate Xcode project from project.yml
- `xcodebuild -project Nagz.xcodeproj -scheme Nagz -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.5' build` — build
- `xcodebuild test -scheme Nagz -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.5'` — run tests (215 as of 2026-02-25)

## Cross-Project Sync
After any change to models, API calls, or shared behavior:
- Always check if `~/nagz-web` needs a matching update
- If the server API changed, models in `Nagz/Models/` and endpoints in `Nagz/Services/APIEndpoint.swift` must be updated
- **Run `xcodegen generate` after adding or removing any Swift file**

## Version Management

All three Nagz repos (nagzerver, nagz-ios, nagz-web) use a shared API versioning scheme.

### How it works
- The server exposes `GET /api/v1/version` (no auth) returning:
  - `server_version` — server release semver (e.g. `0.2.0`)
  - `api_version` — API contract version, bumped on any endpoint change (e.g. `1.0.0`)
  - `min_client_version` — minimum client API version the server supports (e.g. `1.0.0`)
- Each client embeds a `CLIENT_API_VERSION` at build time
- On app launch, `VersionChecker` calls `/version` and compares:
  - **Client < min_client_version** → blocks the app ("Update Required")
  - **Client major < server major** → shows alert ("Update Recommended")
  - **Otherwise** → compatible, no action

### Where versions live

| Repo | File | Constant |
|------|------|----------|
| nagzerver | `src/nagz/core/version.py` | `SERVER_VERSION`, `API_VERSION`, `MIN_CLIENT_VERSION` |
| nagz-ios | `Nagz/Services/VersionChecker.swift` | `VersionChecker.clientAPIVersion` (delegates to Constants) |
| nagz-ios | `Nagz/Config/Constants.swift` | `Constants.Version.clientAPIVersion` |
| nagz-web | `src/version.tsx` | `CLIENT_API_VERSION` |

### When to bump

| Change type | What to bump |
|-------------|-------------|
| New optional field or new endpoint | `API_VERSION` only |
| Breaking change (removed field, changed response shape) | `API_VERSION` + `MIN_CLIENT_VERSION` |
| Server release / deploy | `SERVER_VERSION` |
| Client updated for new API | `CLIENT_API_VERSION` in that client |

### Key files
- **Server**: `src/nagz/core/version.py`, `src/nagz/server/routers/version.py`
- **iOS**: `Nagz/Services/VersionChecker.swift`, `Nagz/Models/VersionModels.swift`
- **Web**: `src/version.tsx` (VersionProvider wraps the app)

## Architecture
- `AIService` injected via `@Environment(\.aiService)` — mirrors `\.apiClient` pattern
  - `NagzAIAdapter` (local NagzAI package heuristics + Foundation Models) with `ServerAIService` fallback
  - `AIInsightsSection` (NagDetailView) — tone, coaching, completion prediction
  - `FamilyInsightsView` (Family tab, guardian-only) — weekly digest + user patterns
- `APIClient` is an `actor` (thread-safe networking, not @Observable)
  - In-memory cache with configurable TTL per endpoint
  - `cachedRequest()` for reads, `invalidateCache(prefix:)` after mutations
  - Auto token refresh on 401 (single retry)
- `AuthManager` is `@Observable @MainActor` — drives auth state for UI
- Dev server URL: `http://127.0.0.1:9800/api/v1` (use IP, not localhost, to avoid IPv6 timeout in simulator)
- JSON coding: `convertFromSnakeCase` / `convertToSnakeCase` handles all field name mapping
  - Exception: models with custom CodingKeys must use plain JSONDecoder in tests
- `ErrorBanner` — reusable error display component with optional retry action
- `APIError.isRetryable` — identifies errors worth retrying (network, server, rate limited)

## Siri & Shortcuts (Implemented)
- Framework: App Intents (iOS 16+), not deprecated SiriKit
- 6 intents in `Nagz/Intents/Actions/`: CreateNag, CompleteNag, ListNags, CheckOverdue, SnoozeNag, FamilyStatus
- Entities in `Nagz/Intents/Entities/`: NagEntity, FamilyMemberEntity, NagCategoryAppEnum
- Queries in `Nagz/Intents/Queries/`: NagEntityQuery, FamilyMemberQuery
- `IntentServiceContainer` — shared lazy KeychainService + APIClient for intents
- `NagzShortcutsProvider` — 6 shortcuts with 14 Siri phrases
- User/family IDs persisted to UserDefaults for intent access (written by AuthManager/FamilyViewModel)
- All intents run in-process (no extension target needed)
- Interactive snippets available (iOS 26 baseline)

## Known Issues & Fixes
- Use `127.0.0.1` not `localhost` in simulator (IPv6 timeout)
- Swift 6: use `nonisolated(unsafe)` for non-Sendable static properties (e.g. ISO8601DateFormatter), `@MainActor` for AppDelegate and notification delegates
- Swift 6: actors (KeychainService, APIClient) are already Sendable — do NOT add `nonisolated(unsafe)` to static lets of actor types
- Swift 6: `AppEntity.defaultQuery` must be a computed property, not stored `var` (concurrency safety)
- Swift Testing: use `@Suite(.serialized)` when tests share mutable global state (e.g., UserDefaults)
- `@MainActor` required on test methods that call `@MainActor` static functions (e.g. `VersionChecker.evaluate`)
- PolicyResponse has custom CodingKeys — use plain `JSONDecoder()` in tests, not the shared `.convertFromSnakeCase` decoder
- Must add explicit `return` in `errorDescription` getter when any case uses if/return (breaks implicit return)
