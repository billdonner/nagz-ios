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

## Architecture
- `APIClient` is an `actor` (thread-safe networking, not @Observable)
- `AuthManager` is `@Observable @MainActor` — drives auth state for UI
- Dev server URL: `http://127.0.0.1:8001/api/v1` (use IP, not localhost, to avoid IPv6 timeout in simulator)
- JSON coding: `convertFromSnakeCase` / `convertToSnakeCase` handles all field name mapping
