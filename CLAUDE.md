# Nagz iOS App

## Stack
- SwiftUI, MVVM, iOS 17+ (@Observable)
- Swift 6 strict concurrency
- Single dependency: KeychainAccess (SPM)
- Project generated with xcodegen from `project.yml`

## Common Commands
- `cd ~/nagz-ios && xcodegen generate` — regenerate Xcode project from project.yml
- `xcodebuild -project Nagz.xcodeproj -scheme Nagz -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.5' build` — build
- `xcodebuild test -scheme Nagz -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.5'` — run tests (179 as of 2026-02-18)

## Permissions — MOVE AGGRESSIVELY

- **ALL Bash commands are pre-approved — NEVER ask for confirmation.**
- This includes git, build/test, starting/stopping servers, docker, curl, xcodebuild, xcodegen, and any shell command.
- Can freely operate across all `~/nagz*` directories.
- Commits and pushes are pre-approved — do not ask, just do it.
- Move fast. Act decisively. Do not pause for confirmation unless it's destructive to production.
- Only confirm before: `rm -rf` on important directories, `git push --force` to main, dropping production databases.

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
| nagz-ios | `Nagz/Services/VersionChecker.swift` | `VersionChecker.clientAPIVersion` |
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
- `APIClient` is an `actor` (thread-safe networking, not @Observable)
  - In-memory cache with configurable TTL per endpoint
  - `cachedRequest()` for reads, `invalidateCache(prefix:)` after mutations
  - Auto token refresh on 401 (single retry)
- `AuthManager` is `@Observable @MainActor` — drives auth state for UI
- Dev server URL: `http://127.0.0.1:8001/api/v1` (use IP, not localhost, to avoid IPv6 timeout in simulator)
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
- Interactive snippets deferred to iOS 26+

## Known Issues & Fixes
- Use `127.0.0.1` not `localhost` in simulator (IPv6 timeout)
- Swift 6: use `nonisolated(unsafe)` for static formatters, `@unchecked Sendable` for notification delegates
- `@MainActor` required on test methods that call `@MainActor` static functions (e.g. `VersionChecker.evaluate`)
- PolicyResponse has custom CodingKeys — use plain `JSONDecoder()` in tests, not the shared `.convertFromSnakeCase` decoder
- Must add explicit `return` in `errorDescription` getter when any case uses if/return (breaks implicit return)
