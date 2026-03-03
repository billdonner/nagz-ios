#if canImport(FoundationModels)
import Foundation
import FoundationModels

// MARK: - List Nags Tool

struct ListNagsTool: Tool {
    let name = "listNags"
    let description = "List the user's nags. Separates tasks ASSIGNED TO the user (their to-do list) from tasks they SENT TO others (monitoring). Use when they ask to see tasks, what's overdue, or what anyone needs to do."

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

        if allNags.isEmpty {
            return "No tasks found matching that criteria."
        }

        // Split into received, sent to others, and self-nags
        let receivedFromOthers = allNags.filter { $0.recipientId == currentUserId && $0.creatorId != currentUserId }
        let sentToOthers = allNags.filter { $0.creatorId == currentUserId && $0.recipientId != currentUserId }
        let selfNags = allNags.filter { $0.creatorId == currentUserId && $0.recipientId == currentUserId }

        let now = Date()
        var parts: [String] = []

        // Lead with YOUR tasks (what the user needs to do)
        let myTasks = receivedFromOthers + selfNags
        let myOverdue = myTasks.filter { $0.dueAt < now }
        parts.append("YOUR TO-DO: \(myTasks.count) task\(myTasks.count == 1 ? "" : "s") assigned to you. \(myOverdue.count) overdue.")

        if !receivedFromOthers.isEmpty {
            for nag in receivedFromOthers.prefix(5) {
                let desc = nag.description ?? nag.category.displayName
                let from = nag.creatorDisplayName ?? "?"
                parts.append("• \(desc) (from \(from))\(nag.dueAt < now ? " OVERDUE" : "")")
            }
        }

        if !selfNags.isEmpty {
            parts.append("Self-reminders:")
            for nag in selfNags.prefix(3) {
                let desc = nag.description ?? nag.category.displayName
                parts.append("• \(desc)\(nag.dueAt < now ? " OVERDUE" : "")")
            }
        }

        // Then monitoring section
        if !sentToOthers.isEmpty {
            let so = sentToOthers.filter { $0.dueAt < now }
            parts.append("MONITORING (sent to others): \(sentToOthers.count) (\(so.count) overdue).")
            for nag in sentToOthers.prefix(5) {
                let desc = nag.description ?? nag.category.displayName
                let to = nag.recipientDisplayName ?? "?"
                parts.append("• \(desc) → \(to)\(nag.dueAt < now ? " OVERDUE" : "")")
            }
        }

        // Don't record a system message for list — the AI response will summarize
        return parts.joined(separator: "\n")
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

        let shortLabel = recipientLabel == "you" ? "you" : recipientLabel
        await collector.record("✓ Nagged \(shortLabel): \(arguments.taskDescription)")
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

        // Search all visible nags, not just ones assigned to me
        let page: PaginatedResponse<NagResponse> = try await apiClient.request(
            .listNags(familyId: familyId, status: .open)
        )
        let nags = page.items

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
        let who = match.recipientDisplayName ?? "someone"
        await collector.record("✓ Completed: \(desc) (\(who))")
        return "Marked \"\(desc)\" (assigned to \(who)) as done!"
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

        // Search all visible nags
        let page: PaginatedResponse<NagResponse> = try await apiClient.request(
            .listNags(familyId: familyId, status: .open)
        )
        let nags = page.items

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
    let description = "Give a quick summary of the user's tasks. Separates tasks ASSIGNED TO the user (their to-do list) from tasks they SENT TO others (monitoring). Use for 'how am I doing?', 'status update', 'what's my workload?', 'who's overdue?'"

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

        let now = Date()
        let received = allNags.filter { $0.recipientId == currentUserId && $0.creatorId != currentUserId }
        let sent = allNags.filter { $0.creatorId == currentUserId && $0.recipientId != currentUserId }
        let selfNags = allNags.filter { $0.creatorId == currentUserId && $0.recipientId == currentUserId }
        let receivedOverdue = received.filter { $0.dueAt < now }
        let selfOverdue = selfNags.filter { $0.dueAt < now }
        let sentOverdue = sent.filter { $0.dueAt < now }

        var parts: [String] = []

        // Lead with YOUR tasks (what the user needs to do)
        let myTaskCount = received.count + selfNags.count
        let myOverdueCount = receivedOverdue.count + selfOverdue.count
        parts.append("YOUR TO-DO: \(myTaskCount) task\(myTaskCount == 1 ? "" : "s") assigned to you. \(myOverdueCount) overdue.")

        if !received.isEmpty {
            parts.append("  From others: \(received.count) (\(receivedOverdue.count) overdue).")
        }
        if !selfNags.isEmpty {
            parts.append("  Self-reminders: \(selfNags.count) (\(selfOverdue.count) overdue).")
        }

        // Then monitoring section (what the user sent to others)
        if !sent.isEmpty {
            parts.append("MONITORING (sent to others): \(sent.count) task\(sent.count == 1 ? "" : "s") (\(sentOverdue.count) overdue).")
            let overdueByPerson = Dictionary(grouping: sentOverdue) { $0.recipientDisplayName ?? "someone" }
            for (name, nags) in overdueByPerson.sorted(by: { $0.key < $1.key }) {
                parts.append("  → \(name): \(nags.count) overdue")
            }
        }

        // Next upcoming task for the user
        let myUpcoming = (received + selfNags).filter { $0.dueAt >= now }.sorted { $0.dueAt < $1.dueAt }
        if let next = myUpcoming.first {
            let desc = next.description ?? next.category.displayName
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relative = formatter.localizedString(for: next.dueAt, relativeTo: now)
            parts.append("Next up for you: \(desc) \(relative).")
        }

        // Check for stale pending invites
        do {
            let pendingPage: PaginatedResponse<ConnectionResponse> = try await apiClient.request(
                .listConnections(status: .pending)
            )
            let staleInvites = pendingPage.items.filter {
                $0.inviterId == currentUserId &&
                Date().timeIntervalSince($0.createdAt) > 5 * 86400
            }
            if !staleInvites.isEmpty {
                parts.append("STALE INVITES: \(staleInvites.count) pending invite\(staleInvites.count == 1 ? " has" : "s have") been waiting 5+ days with no response.")
                for invite in staleInvites {
                    let name = invite.otherPartyDisplayName ?? invite.otherPartyEmail ?? invite.inviteeEmail
                    let days = Int(Date().timeIntervalSince(invite.createdAt) / 86400)
                    parts.append("  → \(name): \(days) days, no response")
                }
                parts.append("Suggest resharing the invite or checking if the email is correct.")
            }
        } catch {
            // Non-critical — skip stale invite check
        }

        let summary = parts.joined(separator: "\n")
        return summary
    }
}

// MARK: - Submit Excuse Tool

struct SubmitExcuseTool: Tool {
    let name = "submitExcuse"
    let description = "Submit an excuse on the user's overdue nags. Use when the user says 'send excuses', 'tell them I'm sick', 'explain why I'm late'. This submits excuses on EXISTING overdue nags — it does NOT create new nags."

    @Generable
    struct Arguments {
        @Guide(description: "The excuse message to submit. Write it as a brief explanation from the user's perspective, e.g. 'I'm not feeling well, will get to it in a couple days.'")
        let excuseText: String

        @Guide(description: "Optional: specific task description to match. Leave empty to submit excuse on ALL overdue nags assigned to the user.")
        let taskDescription: String
    }

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

        // Find overdue nags assigned to current user
        let now = Date()
        let myOverdue = page.items.filter { $0.recipientId == currentUserId && $0.dueAt < now }

        if myOverdue.isEmpty {
            return "You don't have any overdue tasks to excuse."
        }

        // If a specific task is mentioned, filter to just that one
        let targets: [NagResponse]
        let specific = arguments.taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !specific.isEmpty {
            let matched = myOverdue.filter { nag in
                let desc = (nag.description ?? nag.category.displayName).lowercased()
                return desc.contains(specific) || specific.contains(desc)
            }
            targets = matched.isEmpty ? myOverdue : matched
        } else {
            targets = myOverdue
        }

        var submitted = 0
        for nag in targets {
            let _: ExcuseResponse = try await apiClient.request(
                .submitExcuse(nagId: nag.id, text: arguments.excuseText)
            )
            submitted += 1
        }

        let nagNames = targets.prefix(3).map { $0.description ?? $0.category.displayName }
        let nameList = nagNames.joined(separator: ", ")
        await collector.record("✓ Excused \(submitted) nag\(submitted == 1 ? "" : "s"): \(nameList)")
        return "Submitted excuse on \(submitted) overdue nag\(submitted == 1 ? "" : "s"): \(nameList). They'll see: \"\(arguments.excuseText)\""
    }
}

#endif
