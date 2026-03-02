#if canImport(FoundationModels)
import Foundation
import FoundationModels

// MARK: - List Nags Tool

struct ListNagsTool: Tool {
    let name = "listNags"
    let description = "List the user's current nags/tasks. Use when they ask to see their tasks, what's overdue, or what they need to do."

    @Generable
    struct Arguments {
        @Guide(description: "Optional status filter: 'open', 'completed', 'missed', or empty for all open.")
        let status: String
    }

    let apiClient: APIClient
    let familyId: UUID?
    let currentUserId: UUID
    let collector: ToolResultCollector

    nonisolated func call(arguments: Arguments) async throws -> String {
        guard let familyId else {
            await collector.record("📋 No family set up")
            return "No family set up yet — create or join a family first."
        }

        let statusFilter: NagStatus? = switch arguments.status.lowercased() {
        case "completed": .completed
        case "missed": .missed
        case "open", "": .open
        default: .open
        }

        let page: PaginatedResponse<NagResponse> = try await apiClient.request(
            .listNags(familyId: familyId, status: statusFilter)
        )
        let allNags = page.items

        // Filter to nags assigned to current user
        let myNags = allNags.filter { $0.recipientId == currentUserId }

        if myNags.isEmpty {
            await collector.record("📋 No tasks found")
            return "No tasks found matching that criteria."
        }

        let overdue = myNags.filter { $0.dueAt < Date() }
        var summary = "Found \(myNags.count) task\(myNags.count == 1 ? "" : "s")."

        if !overdue.isEmpty {
            summary += " \(overdue.count) overdue."
        }

        let list = myNags.prefix(10).map { nag -> String in
            let desc = nag.description ?? nag.category.displayName
            let due = nag.dueAt < Date() ? "OVERDUE" : "due \(nag.dueAt.formatted(date: .abbreviated, time: .shortened))"
            return "• \(desc) (\(due))"
        }.joined(separator: "\n")

        await collector.record("📋 Listed \(myNags.count) task\(myNags.count == 1 ? "" : "s")")
        return "\(summary)\n\n\(list)"
    }
}

// MARK: - Create Nag Tool

struct CreateNagTool: Tool {
    let name = "createNag"
    let description = "Create a new nag/task/reminder. Use when the user says 'remind me to...', 'nag me about...', or 'add a task'. If they mention someone by name (e.g. 'tell Bobby to...'), set recipientName to that person's name. Leave recipientName empty or set to 'me'/'self' to assign to the current user."

    @Generable
    struct Arguments {
        @Guide(description: "What the user wants to be reminded about.")
        let taskDescription: String

        @Guide(description: "Category: chores, meds, homework, appointments, or other.")
        let category: String

        @Guide(description: "Hours from now until due. Examples: 'tomorrow' = 18, 'in an hour' = 1, 'next week' = 168, 'tonight' = 8.")
        let delayHours: Int

        @Guide(description: "Name of the person to assign this nag to. Leave empty or set to 'me'/'self' to assign to the current user.")
        let recipientName: String
    }

    let apiClient: APIClient
    let familyId: UUID?
    let currentUserId: UUID
    let userName: String
    let collector: ToolResultCollector

    nonisolated func call(arguments: Arguments) async throws -> String {
        let trimmed = arguments.recipientName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let selfKeywords = ["", "me", "self", "myself", userName.lowercased()]
        let isSelfNag = selfKeywords.contains(trimmed)

        let recipientId: UUID
        let recipientLabel: String
        var connectionId: UUID?

        if isSelfNag {
            recipientId = currentUserId
            recipientLabel = "you"
        } else {
            // Fetch family members dynamically
            var people: [(name: String, id: UUID, connectionId: UUID?)] = []

            if let familyId {
                let memberPage: PaginatedResponse<MemberDetail> = try await apiClient.request(
                    .listMembers(familyId: familyId)
                )
                for m in memberPage.items where m.userId != currentUserId {
                    if let name = m.displayName {
                        people.append((name: name, id: m.userId, connectionId: nil))
                    }
                }
            }

            // Fetch connections dynamically
            let connPage: PaginatedResponse<ConnectionResponse> = try await apiClient.request(
                .listConnections(status: .active)
            )
            for conn in connPage.items {
                let otherId = conn.inviterId == currentUserId ? conn.inviteeId : conn.inviterId
                if let otherId, let name = conn.otherPartyDisplayName {
                    // Don't add duplicates (someone might be both family + connection)
                    if !people.contains(where: { $0.id == otherId }) {
                        people.append((name: name, id: otherId, connectionId: conn.id))
                    }
                }
            }

            // Fuzzy match
            let query = trimmed
            let match = people.first(where: { $0.name.lowercased() == query })
                ?? people.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) })
                ?? people.first(where: { fuzzyMatch(query: query, target: $0.name.lowercased()) })

            guard let match else {
                let available = people.map(\.name).joined(separator: ", ")
                let hint = available.isEmpty ? "You don't have any people to nag yet. Add family members or connections first." : "Available people: \(available)."
                await collector.record("❌ Couldn't find \"\(arguments.recipientName)\"")
                return "I couldn't find anyone named \"\(arguments.recipientName)\". \(hint)"
            }

            recipientId = match.id
            recipientLabel = match.name
            connectionId = match.connectionId
        }

        let hours = max(1, min(720, arguments.delayHours))
        let dueAt = Date().addingTimeInterval(Double(hours) * 3600)
        let category = NagCategory(rawValue: arguments.category) ?? .other

        let nag = NagCreate(
            familyId: connectionId == nil ? familyId : nil,
            connectionId: connectionId,
            recipientId: recipientId,
            dueAt: dueAt,
            category: category,
            doneDefinition: .binaryCheck,
            description: arguments.taskDescription
        )

        let created: NagResponse = try await apiClient.request(.createNag(nag))

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateStr = formatter.string(from: created.dueAt)

        await collector.record("✓ Created: \(arguments.taskDescription) for \(recipientLabel) (due \(dateStr))")
        return "Created task \"\(arguments.taskDescription)\" for \(recipientLabel), due \(dateStr)."
    }

    private nonisolated func fuzzyMatch(query: String, target: String) -> Bool {
        let queryWords = query.split(separator: " ")
        let matchCount = queryWords.filter { target.contains($0) }.count
        return matchCount >= max(1, queryWords.count / 2)
    }
}

// MARK: - Complete Nag Tool

struct GlobalCompleteTool: Tool {
    let name = "completeNag"
    let description = "Mark a task as FINISHED. ONLY use when the user says they ALREADY completed a specific task (past tense). Example: 'I took out the trash', 'finished my homework'. Do NOT use for future actions."

    @Generable
    struct Arguments {
        @Guide(description: "Description of the task the user says they finished. Used to fuzzy-match against their task list.")
        let nagDescription: String
    }

    let apiClient: APIClient
    let familyId: UUID?
    let currentUserId: UUID
    let collector: ToolResultCollector

    nonisolated func call(arguments: Arguments) async throws -> String {
        guard let familyId else {
            return "Could not find that task — no family set up."
        }

        let page: PaginatedResponse<NagResponse> = try await apiClient.request(
            .listNags(familyId: familyId, status: .open)
        )
        let allNags = page.items
        let nags = allNags.filter { $0.recipientId == currentUserId }

        let query = arguments.nagDescription.lowercased()
        let match = nags.first { nag in
            let desc = (nag.description ?? nag.category.displayName).lowercased()
            return desc.contains(query) || query.contains(desc) || fuzzyMatch(query: query, target: desc)
        }

        guard let match else {
            await collector.record("❌ Couldn't find matching task")
            return "I couldn't find a task matching \"\(arguments.nagDescription)\". Try listing your tasks first."
        }

        let _: NagResponse = try await apiClient.request(
            .updateNagStatus(nagId: match.id, status: .completed, note: nil)
        )

        let desc = match.description ?? match.category.displayName
        await collector.record("✓ Completed: \(desc)")
        return "Marked \"\(desc)\" as done!"
    }

    private nonisolated func fuzzyMatch(query: String, target: String) -> Bool {
        let queryWords = query.split(separator: " ")
        let matchCount = queryWords.filter { target.contains($0) }.count
        return matchCount >= max(1, queryWords.count / 2)
    }
}

// MARK: - Reschedule Nag Tool

struct GlobalRescheduleTool: Tool {
    let name = "rescheduleNag"
    let description = "Postpone a task to a later time. Use when the user wants to delay, defer, or push back a task. Example: 'do homework tomorrow instead', 'push back trash'."

    @Generable
    struct Arguments {
        @Guide(description: "Description of the task to reschedule. Used to fuzzy-match against task list.")
        let nagDescription: String

        @Guide(description: "Hours to delay from now. Examples: 'tomorrow' = 24, 'next week' = 168, 'a few hours' = 3.")
        let delayHours: Int
    }

    let apiClient: APIClient
    let familyId: UUID?
    let currentUserId: UUID
    let collector: ToolResultCollector

    nonisolated func call(arguments: Arguments) async throws -> String {
        guard let familyId else {
            return "Could not find that task — no family set up."
        }

        let page: PaginatedResponse<NagResponse> = try await apiClient.request(
            .listNags(familyId: familyId, status: .open)
        )
        let allNags = page.items
        let nags = allNags.filter { $0.recipientId == currentUserId }

        let query = arguments.nagDescription.lowercased()
        let match = nags.first { nag in
            let desc = (nag.description ?? nag.category.displayName).lowercased()
            return desc.contains(query) || query.contains(desc) || fuzzyMatch(query: query, target: desc)
        }

        guard let match else {
            await collector.record("❌ Couldn't find matching task")
            return "I couldn't find a task matching \"\(arguments.nagDescription)\". Try listing your tasks first."
        }

        let hours = max(1, min(720, arguments.delayHours))
        let newDue = Date().addingTimeInterval(Double(hours) * 3600)
        let update = NagUpdate(dueAt: newDue, category: nil, doneDefinition: nil)
        let _: NagResponse = try await apiClient.request(.updateNag(nagId: match.id, update: update))

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateStr = formatter.string(from: newDue)

        let desc = match.description ?? match.category.displayName
        await collector.record("✓ Rescheduled \"\(desc)\" to \(dateStr)")
        return "Rescheduled \"\(desc)\" to \(dateStr)."
    }

    private nonisolated func fuzzyMatch(query: String, target: String) -> Bool {
        let queryWords = query.split(separator: " ")
        let matchCount = queryWords.filter { target.contains($0) }.count
        return matchCount >= max(1, queryWords.count / 2)
    }
}

// MARK: - Status Tool

struct NagStatusTool: Tool {
    let name = "nagStatus"
    let description = "Give a quick summary of the user's task load — how many open, overdue, and what's coming up next. Use for 'how am I doing?', 'status update', 'what's my workload?'"

    @Generable
    struct Arguments {}

    let apiClient: APIClient
    let familyId: UUID?
    let currentUserId: UUID
    let collector: ToolResultCollector

    nonisolated func call(arguments: Arguments) async throws -> String {
        guard let familyId else {
            return "No family set up yet."
        }

        let page: PaginatedResponse<NagResponse> = try await apiClient.request(
            .listNags(familyId: familyId, status: .open)
        )
        let allNags = page.items
        let nags = allNags.filter { $0.recipientId == currentUserId }

        let now = Date()
        let overdue = nags.filter { $0.dueAt < now }
        let upcoming = nags.filter { $0.dueAt >= now }.sorted { $0.dueAt < $1.dueAt }

        var parts: [String] = []
        parts.append("You have \(nags.count) open task\(nags.count == 1 ? "" : "s").")

        if !overdue.isEmpty {
            parts.append("\(overdue.count) \(overdue.count == 1 ? "is" : "are") overdue.")
        }

        if let next = upcoming.first {
            let desc = next.description ?? next.category.displayName
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relative = formatter.localizedString(for: next.dueAt, relativeTo: now)
            parts.append("Next up: \(desc) \(relative).")
        }

        let summary = parts.joined(separator: " ")
        await collector.record("📊 Status: \(nags.count) open, \(overdue.count) overdue")
        return summary
    }
}

#endif
