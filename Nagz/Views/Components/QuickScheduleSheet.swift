import SwiftUI

/// Half-sheet with preset time buttons for fast scheduling.
/// Falls back to a graphical date picker for custom times.
struct QuickScheduleSheet: View {
    let nag: NagResponse
    let selectedDate: Date
    let onCommit: (Date) -> Void

    @State private var showCustomPicker = false
    @State private var customDate = Date().addingTimeInterval(3600)
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Nag info header
                    HStack(spacing: 12) {
                        Image(systemName: nag.category.iconName)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nag.description ?? nag.category.displayName)
                                .font(.headline)
                                .lineLimit(2)
                            Text("Due \(nag.dueAt, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(nag.dueAt < Date() ? .red : .secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                    // Quick presets
                    VStack(spacing: 8) {
                        Text("When will you do this?")
                            .font(.subheadline.weight(.medium))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(presets, id: \.label) { preset in
                                Button {
                                    onCommit(preset.date)
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: preset.icon)
                                            .font(.title3)
                                        Text(preset.label)
                                            .font(.callout.weight(.medium))
                                        Text(timeDisplay(preset.date))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // Custom time
                    Button {
                        withAnimation { showCustomPicker.toggle() }
                    } label: {
                        HStack {
                            Label("Pick exact time", systemImage: "clock")
                            Spacer()
                            Image(systemName: showCustomPicker ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .font(.callout)
                        .padding(.horizontal)
                    }

                    if showCustomPicker {
                        DatePicker("", selection: $customDate, in: Date()...,
                                   displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .padding(.horizontal)

                        Button("Commit to this time") {
                            onCommit(customDate)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    // Message about what commitment means
                    Text("You won't be bothered about this task until the committed time passes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.vertical)
            }
            .navigationTitle("Schedule Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Dynamic Presets

    private var presets: [(label: String, icon: String, date: Date)] {
        var results: [(String, String, Date)] = []
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let currentHour = calendar.component(.hour, from: now)

        // Morning (9am) — only if before noon
        if currentHour < 12 {
            let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate)!
            if morning > now {
                results.append(("Morning", "sunrise.fill", morning))
            }
        }

        // Afternoon (2pm) — only if before 2pm
        let afternoon = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: selectedDate)!
        if afternoon > now {
            results.append(("Afternoon", "sun.max.fill", afternoon))
        }

        // Evening (6pm)
        let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: selectedDate)!
        if evening > now {
            results.append(("Evening", "sunset.fill", evening))
        }

        // Tonight (8pm)
        let tonight = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: selectedDate)!
        if tonight > now {
            results.append(("Tonight", "moon.fill", tonight))
        }

        // In 1 hour
        results.append(("In 1 hour", "clock.fill", now.addingTimeInterval(3600)))

        // In 3 hours
        results.append(("In 3 hours", "clock.badge.fill", now.addingTimeInterval(3 * 3600)))

        // Tomorrow morning
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let tomorrowAM = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrowStart)!
        results.append(("Tomorrow AM", "sunrise.fill", tomorrowAM))

        // This weekend (if weekday)
        let weekday = calendar.component(.weekday, from: now)
        if weekday >= 2 && weekday <= 6 {
            let daysUntilSat = 7 - weekday
            let satStart = calendar.date(byAdding: .day, value: daysUntilSat, to: todayStart)!
            let saturday = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: satStart)!
            results.append(("Weekend", "figure.walk", saturday))
        }

        return Array(results.prefix(6))
    }

    private func timeDisplay(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE h:mm a"
        return fmt.string(from: date)
    }
}
