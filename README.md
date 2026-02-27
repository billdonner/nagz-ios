<p align="center">
  <img src="AppIcon-1024.png" alt="Nagz" width="200">
</p>

# Nagz iOS

SwiftUI iOS client for **Nagz**, a family-oriented AI-mediated nagging/reminder app with Apple Intelligence integration.

## Stack

- SwiftUI + MVVM, iOS 26+
- Swift 6 strict concurrency
- Xcode project generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`
- Dependencies: [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess), [GRDB](https://github.com/groue/GRDB.swift) (SPM)

## AI Features

Nagz uses a **split AI architecture** — on-device Foundation Models for natural language, heuristic logic for structured data, and server-side fallback.

Seven of nine AI operations use on-device LLM (Apple Foundation Models) for personalized text. Two operations (patterns, prediction) stay heuristic-only because they're pure math/counting.

| Feature | On-Device LLM | Heuristic | Server Fallback |
|---------|:---:|:---:|:---:|
| Excuse summarization | summary text | category + confidence | `/ai/summarize-excuse` |
| Tone selection | reason text | tone enum | `/ai/select-tone` |
| Coaching tips | personalized tip | scenario + category | `/ai/coaching` |
| Weekly digest | summary text | member stats + totals | `/ai/digest` |
| Push-back reminders | message text | tone + shouldPushBack | `/ai/push-back` |
| List summary | full summary | — | `/ai/list-summary` |
| Gamification nudges | personalized messages | which nudges + icons | — (on-device only) |
| Behavioral patterns | — | day-of-week counting | `/ai/patterns` |
| Completion prediction | — | weighted average | `/ai/predict-completion` |

On-device AI processes text locally — only structured data (categories, status) is shared with the server.

### Siri & Shortcuts (Implemented)

App Intents integration for voice and automation:
- "Show my nags in Nagz" / "What's overdue in Nagz"
- "Create a homework nag for John in Nagz"
- "Mark my nag as done in Nagz"
- Shortcuts automations (morning check, location triggers, end-of-day reports)

See [SIRI_SHORTCUTS.md](https://github.com/billdonner/nagz/blob/main/nagz/Docs/SIRI_SHORTCUTS.md) for the full spec.

## Architecture

| Layer | Key files |
|-------|-----------|
| Models | `Nagz/Models/` — Codable structs for nags, families, auth, gamification, etc. |
| Views | `Nagz/Views/` — SwiftUI views organized by feature (Auth, Nags, Family, Guardian, Safety, Gamification) |
| ViewModels | `Nagz/ViewModels/` — `@Observable` view models |
| Services | `Nagz/Services/` — `APIClient` (actor), `AuthManager`, `KeychainService`, `PushNotificationService`, `VersionChecker` |
| AI | `Nagz/Services/AI/` — `AIService` protocol, `OnDeviceAIService`, `ServerAIService` |
| Local Cache | `Nagz/Database/` — GRDB event cache for offline AI + sync |
| Navigation | `Nagz/Navigation/` — `ContentView`, `AuthenticatedTabView` |

## Getting Started

```bash
# Generate the Xcode project
cd ~/nagz-ios && xcodegen generate

# Open in Xcode
open Nagz.xcodeproj
```

Build and run on an iOS 26+ simulator or device.

The dev server is expected at `http://127.0.0.1:9800/api/v1` (use IP, not `localhost`, to avoid IPv6 timeout in the simulator).

## Tests (215)

```bash
xcodebuild test -project Nagz.xcodeproj -scheme Nagz \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=26.0'
```

## Related Repos

| Repo | Description |
|------|-------------|
| [nagzerver](https://github.com/billdonner/nagzerver) | Python API server (source of truth) |
| [nagz-web](https://github.com/billdonner/nagz-web) | React/TypeScript web client |
| [nagz](https://github.com/billdonner/nagz) | Specs and documentation |
