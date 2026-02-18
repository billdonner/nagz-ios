import Foundation

extension Date {
    private nonisolated(unsafe) static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var relativeDisplay: String {
        let now = Date()
        let interval = timeIntervalSince(now)

        if interval > 0 {
            return Self.relativeFormatter.localizedString(for: self, relativeTo: now)
        } else {
            let absInterval = -interval
            if absInterval < 60 {
                return "just now"
            }
            let relative = Self.relativeFormatter.localizedString(for: self, relativeTo: now)
            if absInterval > 3600 {
                return "\(relative) (overdue)"
            }
            return relative
        }
    }

    var shortDisplay: String {
        Self.shortFormatter.string(from: self)
    }
}
