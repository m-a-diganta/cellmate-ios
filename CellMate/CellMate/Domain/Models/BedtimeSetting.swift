import Foundation

/// Bedtime is stored as minutes after midnight (10:30 pm = 1350).
/// The risk rules and the alerts read this value.
enum BedtimeSetting {
    static let defaultMinutes = 22 * 60 + 30

    static func date(fromMinutes minutes: Int, on day: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func displayText(minutes: Int) -> String {
        date(fromMinutes: minutes).formatted(date: .omitted, time: .shortened)
    }
}
