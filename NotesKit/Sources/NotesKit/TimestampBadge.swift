import Foundation

public extension Date {
    /// Short text for a timestamp badge: the time for today, otherwise the date,
    /// with the year only when it differs from `now`'s.
    func timestampBadge(relativeTo now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        if calendar.isDate(self, inSameDayAs: now) {
            style = style.hour().minute()
        } else if calendar.isDate(self, equalTo: now, toGranularity: .year) {
            style = style.day().month(.abbreviated)
        } else {
            style = style.day().month(.abbreviated).year()
        }
        return formatted(style)
    }
}
