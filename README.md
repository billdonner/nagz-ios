# Nagz iOS

SwiftUI iOS client for **Nagz**, a family-oriented AI-mediated nagging/reminder app.

## Stack

- SwiftUI + MVVM, iOS 17+
- Swift 6 strict concurrency
- Xcode project generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`
- Single dependency: [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) (SPM)

## Architecture

| Layer | Key files |
|-------|-----------|
| Models | `Nagz/Models/` — Codable structs for nags, families, auth, gamification, etc. |
| Views | `Nagz/Views/` — SwiftUI views organized by feature (Auth, Nags, Family, Guardian, Safety, Gamification) |
| ViewModels | `Nagz/ViewModels/` — `@Observable` view models |
| Services | `Nagz/Services/` — `APIClient` (actor), `AuthManager`, `KeychainService`, `PushNotificationService`, `VersionChecker` |
| Navigation | `Nagz/Navigation/` — `ContentView`, `AuthenticatedTabView` |

## Getting Started

```bash
# Generate the Xcode project
cd ~/nagz-ios && xcodegen generate

# Open in Xcode
open Nagz.xcodeproj
```

Build and run on an iOS 17+ simulator or device.

The dev server is expected at `http://127.0.0.1:8001/api/v1` (use IP, not `localhost`, to avoid IPv6 timeout in the simulator).

## Tests (166)

```bash
xcodebuild test -project Nagz.xcodeproj -scheme Nagz \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.5'
```

## Related Repos

| Repo | Description |
|------|-------------|
| [nagzerver](https://github.com/billdonner/nagzerver) | Python API server (source of truth) |
| [nagz-web](https://github.com/billdonner/nagz-web) | React/TypeScript web client |
| [nagz](https://github.com/billdonner/nagz) | Specs and documentation |
