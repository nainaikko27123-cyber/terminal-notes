import Foundation
import Testing
@testable import NotesKit

@Suite struct TimestampBadgeTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    let locale = Locale(identifier: "en_GB")

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func badge(_ date: Date, now: Date) -> String {
        date.timestampBadge(relativeTo: now, calendar: calendar, locale: locale)
    }

    @Test func todayShowsTheTime() {
        #expect(badge(date(2026, 11, 2, 8, 15), now: date(2026, 11, 2, 23, 0)) == "08:15")
    }

    @Test func yesterdayJustBeforeMidnightShowsTheDate() {
        #expect(badge(date(2026, 11, 1, 23, 59), now: date(2026, 11, 2, 0, 1)) == "1 Nov")
    }

    @Test func lastYearIncludesTheYear() {
        #expect(badge(date(2025, 12, 31), now: date(2026, 1, 1)) == "31 Dec 2025")
    }
}
