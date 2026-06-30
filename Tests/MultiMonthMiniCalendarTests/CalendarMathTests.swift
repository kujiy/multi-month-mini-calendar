import XCTest
@testable import MultiMonthMiniCalendar

final class CalendarMathTests: XCTestCase {

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private var utcCalendar: Calendar {
        var cal = CalendarMath.calendar(weekStart: .monday)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    // MARK: shift

    func testShiftForward() {
        let base = MonthIdentifier(year: 2026, month: 11)
        XCTAssertEqual(CalendarMath.shift(base, by: 1), MonthIdentifier(year: 2026, month: 12))
        XCTAssertEqual(CalendarMath.shift(base, by: 2), MonthIdentifier(year: 2027, month: 1))
        XCTAssertEqual(CalendarMath.shift(base, by: 14), MonthIdentifier(year: 2028, month: 1))
    }

    func testShiftBackwardAcrossYear() {
        let base = MonthIdentifier(year: 2026, month: 2)
        XCTAssertEqual(CalendarMath.shift(base, by: -1), MonthIdentifier(year: 2026, month: 1))
        XCTAssertEqual(CalendarMath.shift(base, by: -2), MonthIdentifier(year: 2025, month: 12))
        XCTAssertEqual(CalendarMath.shift(base, by: -13), MonthIdentifier(year: 2025, month: 1))
    }

    // MARK: base month

    func testBaseMonthCurrent() {
        let base = CalendarMath.baseMonth(
            startingMonth: .currentMonth,
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar
        )
        XCTAssertEqual(base, MonthIdentifier(year: 2026, month: 6))
    }

    func testBaseMonthJanuary() {
        let base = CalendarMath.baseMonth(
            startingMonth: .january,
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar
        )
        XCTAssertEqual(base, MonthIdentifier(year: 2026, month: 1))
    }

    func testBaseMonthPrevious() {
        let base = CalendarMath.baseMonth(
            startingMonth: .previousMonth,
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar
        )
        XCTAssertEqual(base, MonthIdentifier(year: 2026, month: 5))
    }

    func testBaseMonthPreviousWrapsAcrossYear() {
        let base = CalendarMath.baseMonth(
            startingMonth: .previousMonth,
            referenceDate: date(2026, 1, 15),
            calendar: utcCalendar
        )
        XCTAssertEqual(base, MonthIdentifier(year: 2025, month: 12))
    }

    // MARK: months to display

    func testMonthsToDisplayDefault() {
        let months = CalendarMath.monthsToDisplay(
            startingMonth: .currentMonth,
            count: 2,
            offset: 0,
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar
        )
        XCTAssertEqual(months, [
            MonthIdentifier(year: 2026, month: 6),
            MonthIdentifier(year: 2026, month: 7)
        ])
    }

    func testMonthsToDisplayWithOffsetWraps() {
        let months = CalendarMath.monthsToDisplay(
            startingMonth: .currentMonth,
            count: 2,
            offset: 7, // June + 7 = January next year
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar
        )
        XCTAssertEqual(months, [
            MonthIdentifier(year: 2027, month: 1),
            MonthIdentifier(year: 2027, month: 2)
        ])
    }

    func testThreeMonthsIncludingLastMonth() {
        // "Last Month": prev, current, next — today's month always 2nd.
        let months = CalendarMath.monthsToDisplay(
            startingMonth: .previousMonth,
            count: 3,
            offset: 0,
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar
        )
        XCTAssertEqual(months, [
            MonthIdentifier(year: 2026, month: 5),
            MonthIdentifier(year: 2026, month: 6),
            MonthIdentifier(year: 2026, month: 7)
        ])
    }

    func testTwelveMonthsFromJanuary() {
        let months = CalendarMath.monthsToDisplay(
            startingMonth: .january,
            count: 12,
            offset: 0,
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar
        )
        XCTAssertEqual(months.count, 12)
        XCTAssertEqual(months.first, MonthIdentifier(year: 2026, month: 1))
        XCTAssertEqual(months.last, MonthIdentifier(year: 2026, month: 12))
    }

    // MARK: grid

    func testGridJune2026MondayStart() {
        // June 1, 2026 is a Monday. With Monday start there should be no leading blanks.
        let rows = CalendarMath.grid(
            for: MonthIdentifier(year: 2026, month: 6),
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar
        )
        XCTAssertEqual(rows.first?.first?.day, 1)
        XCTAssertEqual(rows.first?.first?.weekday, 2) // Monday
        // 30 days fit; verify total day cells.
        let dayCount = rows.flatMap { $0 }.compactMap(\.day).count
        XCTAssertEqual(dayCount, 30)
        // Every row has exactly 7 cells.
        XCTAssertTrue(rows.allSatisfy { $0.count == 7 })
    }

    func testGridJune2026SundayStartHasLeadingBlank() {
        var cal = CalendarMath.calendar(weekStart: .sunday)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // June 1, 2026 is Monday → with Sunday start, one leading blank.
        let rows = CalendarMath.grid(
            for: MonthIdentifier(year: 2026, month: 6),
            referenceDate: date(2026, 6, 30),
            calendar: cal
        )
        XCTAssertNil(rows.first?.first?.day) // Sunday blank
        XCTAssertEqual(rows.first?[1].day, 1) // Monday = day 1
    }

    func testTodayIsFlagged() {
        let rows = CalendarMath.grid(
            for: MonthIdentifier(year: 2026, month: 6),
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar
        )
        let today = rows.flatMap { $0 }.filter(\.isToday)
        XCTAssertEqual(today.count, 1)
        XCTAssertEqual(today.first?.day, 30)
    }

    func testTodayNotInOtherMonth() {
        let rows = CalendarMath.grid(
            for: MonthIdentifier(year: 2026, month: 7),
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar
        )
        XCTAssertFalse(rows.flatMap { $0 }.contains { $0.isToday })
    }

    // MARK: holidays

    func testGridFlagsHolidayDays() {
        let rows = CalendarMath.grid(
            for: MonthIdentifier(year: 2026, month: 1),
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar,
            holidayDays: [1, 12]
        )
        let cells = rows.flatMap { $0 }
        XCTAssertTrue(cells.first { $0.day == 1 }?.isHoliday ?? false)
        XCTAssertTrue(cells.first { $0.day == 12 }?.isHoliday ?? false)
        XCTAssertFalse(cells.first { $0.day == 2 }?.isHoliday ?? true)
        // Padding cells are never holidays.
        XCTAssertFalse(cells.filter { $0.day == nil }.contains { $0.isHoliday })
    }

    func testGridNoHolidaysByDefault() {
        let rows = CalendarMath.grid(
            for: MonthIdentifier(year: 2026, month: 1),
            referenceDate: date(2026, 6, 30),
            calendar: utcCalendar
        )
        XCTAssertFalse(rows.flatMap { $0 }.contains { $0.isHoliday })
    }

    // MARK: headers

    func testWeekdayHeadersMonday() {
        let headers = CalendarMath.weekdayHeaders(calendar: utcCalendar)
        XCTAssertEqual(headers.count, 7)
        // Monday-first: first header weekday should map to Monday (2).
        XCTAssertEqual(CalendarMath.weekday(forColumn: 0, calendar: utcCalendar), 2)
        XCTAssertEqual(CalendarMath.weekday(forColumn: 6, calendar: utcCalendar), 1) // Sunday last
    }

    // MARK: localized titles

    func testMonthTitleEnglish() {
        var cal = utcCalendar
        cal.locale = Locale(identifier: "en_US")
        let title = CalendarMath.monthTitle(MonthIdentifier(year: 2026, month: 6), calendar: cal)
        XCTAssertEqual(title, "June 2026")
    }

    func testMonthTitleGerman() {
        var cal = utcCalendar
        cal.locale = Locale(identifier: "de_DE")
        let title = CalendarMath.monthTitle(MonthIdentifier(year: 2026, month: 6), calendar: cal)
        XCTAssertEqual(title, "Juni 2026")
    }

    func testMonthTitleIsLocalizedNotIso() {
        // Regression: must not produce the non-localized "M06" style output.
        var cal = utcCalendar
        cal.locale = Locale(identifier: "en_US")
        let title = CalendarMath.monthTitle(MonthIdentifier(year: 2026, month: 6), calendar: cal)
        XCTAssertFalse(title.contains("M06"))
    }

    func testWeekdayHeadersSunday() {
        var cal = CalendarMath.calendar(weekStart: .sunday)
        cal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(CalendarMath.weekday(forColumn: 0, calendar: cal), 1) // Sunday first
        XCTAssertEqual(CalendarMath.weekday(forColumn: 6, calendar: cal), 7) // Saturday last
    }
}
