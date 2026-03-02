import SwiftUI

struct ScheduleNagListView: View {
    let nagsForMe: [NagResponse]
    let nagsForOthers: [NagResponse]
    let selfNags: [NagResponse]
    let currentUserId: UUID?
    let onSchedule: (UUID) -> Void

    private var sections: [ScheduleSection] {
        Self.groupNagsByDate(
            nagsForMe: nagsForMe,
            nagsForOthers: nagsForOthers,
            selfNags: selfNags,
            currentUserId: currentUserId,
            referenceDate: Date()
        )
    }

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.nags) { entry in
                        NavigationLink(value: entry.nag.id) {
                            NagRowView(nag: entry.nag, currentUserId: currentUserId)
                        }
                        .swipeActions(edge: .trailing) {
                            if entry.canSchedule {
                                Button {
                                    onSchedule(entry.nag.id)
                                } label: {
                                    Label("Schedule", systemImage: "clock.badge.checkmark")
                                }
                                .tint(.purple)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(section.title)
                            .foregroundStyle(section.headerColor)
                        if section.kind == .unscheduled {
                            Spacer()
                            Text("Tap clock to schedule")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Grouping Logic

    enum SectionKind: Hashable, Comparable {
        case overdue
        case today
        case tomorrow
        case futureDay(Date)
        case later
        case unscheduled

        var sortOrder: Int {
            switch self {
            case .overdue: return 0
            case .today: return 1
            case .tomorrow: return 2
            case .futureDay: return 3
            case .later: return 4
            case .unscheduled: return 5
            }
        }

        static func < (lhs: SectionKind, rhs: SectionKind) -> Bool {
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            if case .futureDay(let ld) = lhs, case .futureDay(let rd) = rhs {
                return ld < rd
            }
            return false
        }
    }

    struct ScheduleEntry: Identifiable {
        let nag: NagResponse
        let canSchedule: Bool
        var id: UUID { nag.id }
    }

    struct ScheduleSection: Identifiable {
        let kind: SectionKind
        let title: String
        let headerColor: Color
        let nags: [ScheduleEntry]
        var id: SectionKind { kind }
    }

    static func groupNagsByDate(
        nagsForMe: [NagResponse],
        nagsForOthers: [NagResponse],
        selfNags: [NagResponse],
        currentUserId: UUID?,
        referenceDate: Date
    ) -> [ScheduleSection] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: referenceDate)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: todayStart)!
        let futureLimit = calendar.date(byAdding: .day, value: 15, to: todayStart)!

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE, MMM d"

        var buckets: [SectionKind: [ScheduleEntry]] = [:]

        func addToBucket(_ nag: NagResponse, canSchedule: Bool) {
            let effectiveDate = nag.committedAt ?? nag.dueAt
            let dayStart = calendar.startOfDay(for: effectiveDate)
            let isOpen = nag.status == .open

            let kind: SectionKind
            if dayStart < todayStart && isOpen {
                kind = .overdue
            } else if dayStart >= todayStart && dayStart < tomorrowStart {
                kind = .today
            } else if dayStart >= tomorrowStart && dayStart < dayAfterTomorrow {
                kind = .tomorrow
            } else if dayStart >= dayAfterTomorrow && dayStart < futureLimit {
                kind = .futureDay(dayStart)
            } else if dayStart >= futureLimit {
                kind = .later
            } else {
                // Past but not open (completed/missed) — put under its actual date
                if dayStart >= todayStart && dayStart < tomorrowStart {
                    kind = .today
                } else if dayStart >= tomorrowStart && dayStart < dayAfterTomorrow {
                    kind = .tomorrow
                } else if dayStart >= dayAfterTomorrow && dayStart < futureLimit {
                    kind = .futureDay(dayStart)
                } else {
                    kind = .later
                }
            }

            let entry = ScheduleEntry(nag: nag, canSchedule: canSchedule)
            buckets[kind, default: []].append(entry)
        }

        // Received nags: unscheduled if open + no committedAt, otherwise by date
        for nag in nagsForMe {
            if nag.status == .open && nag.committedAt == nil {
                let entry = ScheduleEntry(nag: nag, canSchedule: true)
                buckets[.unscheduled, default: []].append(entry)
            } else {
                addToBucket(nag, canSchedule: false)
            }
        }

        // Sent nags: always go under dueAt date, never unscheduled
        for nag in nagsForOthers {
            addToBucket(nag, canSchedule: false)
        }

        // Self nags: go under dueAt date, not unscheduled
        for nag in selfNags {
            addToBucket(nag, canSchedule: false)
        }

        // Sort entries within each bucket by time ascending
        for key in buckets.keys {
            buckets[key]?.sort { a, b in
                let aTime = a.nag.committedAt ?? a.nag.dueAt
                let bTime = b.nag.committedAt ?? b.nag.dueAt
                return aTime < bTime
            }
        }

        // Build sections
        return buckets.keys.sorted().compactMap { kind in
            guard let entries = buckets[kind], !entries.isEmpty else { return nil }
            let title: String
            let color: Color
            switch kind {
            case .overdue:
                title = "Overdue"
                color = .red
            case .today:
                title = "Today"
                color = .blue
            case .tomorrow:
                title = "Tomorrow"
                color = .primary
            case .futureDay(let date):
                title = dayFormatter.string(from: date)
                color = .primary
            case .later:
                title = "Later"
                color = .primary
            case .unscheduled:
                title = "Unscheduled"
                color = .purple
            }
            return ScheduleSection(kind: kind, title: title, headerColor: color, nags: entries)
        }
    }
}
