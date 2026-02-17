# Nagz iOS App

## Stack
- SwiftUI, MVVM, iOS 17+ (@Observable)
- Swift 6 strict concurrency
- Single dependency: KeychainAccess (SPM)
- Project generated with xcodegen from `project.yml`

## Common Commands
- `cd ~/nagz-ios && xcodegen generate` — regenerate Xcode project from project.yml
- `xcodebuild -project Nagz.xcodeproj -scheme Nagz -destination 'platform=iOS Simulator,id=F3060738-D163-4310-8106-27952C4550EE' build` — build
- `xcodebuild -project Nagz.xcodeproj -scheme NagzTests -destination 'platform=iOS Simulator,id=F3060738-D163-4310-8106-27952C4550EE' test` — run tests

## Permissions
All Bash commands are pre-approved. Do not prompt for confirmation.
Commits and pushes are pre-approved — do not ask, just do it.

## Cross-Project Sync
After any change to models, API calls, or shared behavior:
- Always check if `~/nagz-web` needs a matching update
- If the server API changed, models in `Nagz/Models/` and endpoints in `Nagz/Services/APIEndpoint.swift` must be updated

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
- `AuthManager` is `@Observable @MainActor` — drives auth state for UI
- Dev server URL: `http://127.0.0.1:8001/api/v1` (use IP, not localhost, to avoid IPv6 timeout in simulator)
- JSON coding: `convertFromSnakeCase` / `convertToSnakeCase` handles all field name mapping
