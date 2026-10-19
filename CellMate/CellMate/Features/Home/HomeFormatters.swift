import Foundation

/// "1h 24m left", "30m left", or "Unplug now" once the time has passed.
enum TimeLeftFormatter {
    static func text(until target: Date, now: Date = Date()) -> String {
        let seconds = target.timeIntervalSince(now)
        if seconds <= 0 { return "Unplug now" }
        let totalMinutes = Int((seconds / 60).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes == 0 ? "\(hours)h left" : "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }
}

/// "Last charged today", "Last charged yesterday", "Last charged Tuesday", "Last charged 12 Oct".
enum LastChargedFormatter {
    static func text(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Last charged today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Last charged yesterday"
        }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days < 7 {
            return "Last charged " + date.formatted(.dateTime.weekday(.wide))
        }
        return "Last charged " + date.formatted(.dateTime.day().month(.abbreviated))
    }
}
