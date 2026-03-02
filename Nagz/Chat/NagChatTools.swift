#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Collects tool action messages during a respond() call so the VM
/// can display system messages (e.g. "✓ Rescheduled to Mar 5").
actor ToolResultCollector {
    private var actions: [String] = []

    func record(_ action: String) {
        actions.append(action)
    }

    func drain() -> [String] {
        let result = actions
        actions.removeAll()
        return result
    }
}

// MARK: - Reschedule Tool

/// Lets the AI reschedule a nag by a specified number of hours.
struct RescheduleTool: Tool {
    let name = "rescheduleNag"
    let description = "Postpone this task to a later time. Use when the user wants to delay, defer, or do it tomorrow/later. Example: 'Can I do this tomorrow' means reschedule by 24 hours."

    @Generable
    struct Arguments {
        @Guide(description: "Number of hours to delay, from 1 to 168 (one week).")
        let delayHours: Int
    }

    let nagId: UUID
    let apiClient: APIClient
    let collector: ToolResultCollector

    nonisolated func call(arguments: Arguments) async throws -> String {
        let hours = max(1, min(168, arguments.delayHours))
        let newDue = Date().addingTimeInterval(Double(hours) * 3600)
        let update = NagUpdate(dueAt: newDue, category: nil, doneDefinition: nil)
        let _: NagResponse = try await apiClient.request(.updateNag(nagId: nagId, update: update))

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateStr = formatter.string(from: newDue)
        await collector.record("✓ Rescheduled to \(dateStr)")
        return "Rescheduled to \(dateStr)."
    }
}

// MARK: - Complete Tool

/// Lets the AI mark a nag as completed.
struct CompleteTool: Tool {
    let name = "completeNag"
    let description = "Mark this task as FINISHED. ONLY use when the user confirms they ALREADY completed the task (past tense). Never use when the user asks to do it later or tomorrow — that is a reschedule."

    @Generable
    struct Arguments {
        @Guide(description: "Optional completion note from the user. Use empty string if none.")
        let note: String
    }

    let nagId: UUID
    let apiClient: APIClient
    let collector: ToolResultCollector

    nonisolated func call(arguments: Arguments) async throws -> String {
        let noteValue = arguments.note.isEmpty ? nil : arguments.note
        let _: NagResponse = try await apiClient.request(
            .updateNagStatus(nagId: nagId, status: .completed, note: noteValue)
        )
        await collector.record("✓ Marked as complete")
        return "Marked as done!"
    }
}

// MARK: - Excuse Tool

/// Lets the AI submit a formal excuse on behalf of the user.
struct ExcuseTool: Tool {
    let name = "submitExcuse"
    let description = "Submit a formal excuse to the person who created this nag. Use when the user wants their reason sent for review."

    @Generable
    struct Arguments {
        @Guide(description: "The excuse reason to submit.")
        let reason: String
    }

    let nagId: UUID
    let apiClient: APIClient
    let collector: ToolResultCollector

    nonisolated func call(arguments: Arguments) async throws -> String {
        let _: ExcuseResponse = try await apiClient.request(
            .submitExcuse(nagId: nagId, text: arguments.reason)
        )
        await collector.record("✓ Excuse submitted for review")
        return "Excuse submitted for review."
    }
}

#endif
