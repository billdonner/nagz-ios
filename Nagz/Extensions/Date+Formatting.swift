import Foundation

extension Date {
    var relativeDisplay: String {
        let now = Date()
        let interval = timeIntervalSince(now)

        if interval > 0 {
            // Future
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: self, relativeTo: now)
        } else {
            // Past / overdue
            let absInterval = -interval
            if absInterval < 60 {
                return "just now"
            }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relative = formatter.localizedString(for: self, relativeTo: now)
            if absInterval > 3600 {
                return "\(relative) (overdue)"
            }
            return relative
        }
    }

    var shortDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
