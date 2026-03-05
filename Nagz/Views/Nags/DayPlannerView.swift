import SwiftUI

/// Hourly day-planner view: shows a date strip, unscheduled inbox, and hourly timeline.
/// Users tap unscheduled nags to assign them to a time slot via QuickScheduleSheet.
struct DayPlannerView: View {
    let nags: [NagResponse]
    let currentUserId: UUID?
    let onCommit: (UUID, Date) -> Void
    var onUncommit: ((UUID) -> Void)?
    var onCreateAtTime: ((Date) -> Void)?
    var onCreateForDay: ((Date) -> Void)?

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var schedulingNag: NagResponse?

    private let calendar = Calendar.current
    private let startHour = 6
    private let endHour = 23

    // Open nags assigned to me (received + self-nags)
    private var myOpenNags: [NagResponse] {
        guard let userId = currentUserId else { return nags.filter { $0.status == .open } }
        return nags.filter { $0.recipientId == userId && $0.status == .open }
    }

    // Nags with committedAt on the selected day
    private var scheduledForDay: [NagResponse] {
        myOpenNags.filter { nag in
            guard let committed = nag.committedAt else { return false }
            return calendar.isDate(committed, inSameDayAs: selectedDate)
        }.sorted { ($0.committedAt ?? $0.dueAt) < ($1.committedAt ?? $1.dueAt) }
    }

    // Nags due on selected day with no committedAt
    private var dueForDay: [NagResponse] {
        myOpenNags.filter { nag in
            nag.committedAt == nil && calendar.isDate(nag.dueAt, inSameDayAs: selectedDate)
        }.sorted { $0.dueAt < $1.dueAt }
    }

    // All unscheduled nags (no committedAt)
    private var unscheduled: [NagResponse] {
        myOpenNags.filter { $0.committedAt == nil }.sorted { $0.dueAt < $1.dueAt }
    }

    // Nags placed on the timeline for the selected day
    private var timelineNags: [NagResponse] {
        (scheduledForDay + dueForDay).sorted {
            let aTime = $0.committedAt ?? $0.dueAt
            let bTime = $1.committedAt ?? $1.dueAt
            return aTime < bTime
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            dateStrip

            ScrollView {
                if !unscheduled.isEmpty {
                    unscheduledSection
                }

                hourlyTimeline
                    .padding(.bottom, 40)
            }
        }
        .sheet(item: $schedulingNag) { nag in
            QuickScheduleSheet(nag: nag, selectedDate: selectedDate) { date in
                onCommit(nag.id, date)
                schedulingNag = nil
            }
        }
    }

    // MARK: - Date Strip

    private var dateStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<8, id: \.self) { offset in
                    let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
                    let selected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let count = nagsForDay(date)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedDate = date }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 2) {
                                Text(dayLabel(date))
                                    .font(.caption2)
                                    .foregroundStyle(selected ? .white : .secondary)
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(selected ? .white : .primary)
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(selected ? .white.opacity(0.8) : .blue)
                                }
                            }
                            .frame(width: 48, height: 60)
                            .background(selected ? Color.blue : Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))

                            if selected, onCreateForDay != nil {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                            onCreateForDay?(date)
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func dayLabel(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tmrw" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }

    private func nagsForDay(_ date: Date) -> Int {
        myOpenNags.filter { nag in
            let effective = nag.committedAt ?? nag.dueAt
            return calendar.isDate(effective, inSameDayAs: date)
        }.count
    }

    // MARK: - Unscheduled Inbox

    private var unscheduledSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(.purple)
                Text("Unscheduled")
                    .font(.subheadline.weight(.semibold))
                Text("(\(unscheduled.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Tap to schedule")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(unscheduled) { nag in
                        Button { schedulingNag = nag } label: {
                            compactNagCard(nag)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(.purple.opacity(0.04))
    }

    private func compactNagCard(_ nag: NagResponse) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: nag.category.iconName)
                .font(.caption)
                .foregroundStyle(nag.dueAt < Date() ? .orange : .secondary)
            Text(nag.description ?? nag.category.displayName)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if nag.dueAt < Date() {
                Text("OVERDUE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
            } else {
                Text("Due \(nag.dueAt, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100, alignment: .leading)
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    // MARK: - Hourly Timeline

    private var hourlyTimeline: some View {
        VStack(spacing: 0) {
            ForEach(startHour...endHour, id: \.self) { hour in
                hourSlot(hour: hour)
            }
        }
        .padding(.horizontal)
    }

    private func hourSlot(hour: Int) -> some View {
        let nagsInSlot = timelineNags.filter { nag in
            let time = nag.committedAt ?? nag.dueAt
            return calendar.component(.hour, from: time) == hour
        }
        let isCurrentHour = calendar.isDateInToday(selectedDate) && calendar.component(.hour, from: Date()) == hour

        return HStack(alignment: .top, spacing: 8) {
            // Time label
            Text(hourLabel(hour))
                .font(.caption.monospacedDigit())
                .foregroundStyle(isCurrentHour ? .blue : .secondary)
                .frame(width: 44, alignment: .trailing)

            // Timeline bar
            VStack(spacing: 0) {
                if isCurrentHour {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }
                Rectangle()
                    .fill(isCurrentHour ? Color.blue : Color.gray.opacity(0.2))
                    .frame(width: isCurrentHour ? 2 : 1)
            }

            // Nags in this slot
            VStack(alignment: .leading, spacing: 4) {
                if nagsInSlot.isEmpty {
                    Button {
                        let slotDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate)!
                        onCreateAtTime?(slotDate)
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .font(.caption2)
                                .foregroundStyle(Color.gray.opacity(0.35))
                            Spacer()
                        }
                        .frame(height: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(nagsInSlot) { nag in
                        Button { schedulingNag = nag } label: {
                            timelineNagRow(nag)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if nag.committedAt != nil {
                                Button("Remove from Schedule", role: .destructive) {
                                    onUncommit?(nag.id)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: nagsInSlot.isEmpty ? 32 : 44)
    }

    private func timelineNagRow(_ nag: NagResponse) -> some View {
        let isCommitted = nag.committedAt != nil

        return HStack(spacing: 8) {
            Image(systemName: nag.category.iconName)
                .font(.caption)
                .foregroundStyle(categoryColor(nag.category))

            VStack(alignment: .leading, spacing: 2) {
                Text(nag.description ?? nag.category.displayName)
                    .font(.callout)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let name = nag.creatorDisplayName, nag.creatorId != currentUserId {
                        Text("From \(name)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if isCommitted {
                        Label("Committed", systemImage: "clock.badge.checkmark")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    } else {
                        Text("Due")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Image(systemName: "clock")
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isCommitted ? Color.purple.opacity(0.06) : Color.orange.opacity(0.06),
                     in: RoundedRectangle(cornerRadius: 6))
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "am" : "pm"
        return "\(h)\(suffix)"
    }

    private func categoryColor(_ cat: NagCategory) -> Color {
        switch cat {
        case .chores: .brown
        case .meds: .pink
        case .homework: .blue
        case .appointments: .purple
        case .other: .gray
        }
    }
}
