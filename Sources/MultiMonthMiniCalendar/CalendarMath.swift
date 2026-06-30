import Foundation

/// A single month's identity (year + 1-based month).
struct MonthIdentifier: Equatable, Hashable {
    var year: Int
    var month: Int // 1...12
}

/// One day cell in a month grid. `day == nil` marks a cell that belongs to an
/// adjacent month; such cells carry the spill-over day number in `adjacentDay`
/// and are rendered faintly.
struct DayCell: Equatable {
    /// Day of month for the cell's own month, or `nil` for adjacent-month cells.
    var day: Int?
    /// For adjacent-month cells (`day == nil`), the day number of the previous
    /// or next month shown faintly in the leading/trailing slots. `nil` for
    /// cells that belong to this month.
    var adjacentDay: Int?
    /// Weekday: 1 = Sunday ... 7 = Saturday (matches `Calendar` component).
    var weekday: Int?
    /// True when this cell is "today".
    var isToday: Bool
    /// True when this day is a public holiday in the active region.
    var isHoliday: Bool = false
}

/// Pure date computations. No UI, no global state — every entry point takes an
/// explicit reference date and `Calendar` so the logic is deterministic and
/// testable.
enum CalendarMath {

    /// Builds a `Calendar` (Gregorian) configured for the given week start.
    /// The locale follows the system setting so month/weekday names are
    /// localized (e.g. "June 2026" / "Juni 2026"). The week start is still
    /// driven explicitly by the user preference, overriding the locale default.
    static func calendar(weekStart: WeekStart) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = .autoupdatingCurrent
        cal.firstWeekday = weekStart.firstWeekday
        return cal
    }

    /// The base (anchor) month for the display range, before navigation offset.
    /// - `currentMonth`: the month containing `referenceDate`.
    /// - `january`: January of the year containing `referenceDate`.
    static func baseMonth(
        startingMonth: StartingMonth,
        referenceDate: Date,
        calendar: Calendar
    ) -> MonthIdentifier {
        let comps = calendar.dateComponents([.year, .month], from: referenceDate)
        let year = comps.year ?? 2000
        switch startingMonth {
        case .currentMonth:
            return MonthIdentifier(year: year, month: comps.month ?? 1)
        case .previousMonth:
            let current = MonthIdentifier(year: year, month: comps.month ?? 1)
            return shift(current, by: -1)
        case .january:
            return MonthIdentifier(year: year, month: 1)
        }
    }

    /// Adds `delta` months to a `MonthIdentifier`, normalizing year/month.
    static func shift(_ base: MonthIdentifier, by delta: Int) -> MonthIdentifier {
        // Convert to a zero-based absolute month count to normalize cleanly.
        let absolute = base.year * 12 + (base.month - 1) + delta
        let year = absolute / 12
        let monthZero = absolute % 12
        // Handle negative modulo (years before 0 are irrelevant in practice).
        if monthZero < 0 {
            return MonthIdentifier(year: year - 1, month: monthZero + 12 + 1)
        }
        return MonthIdentifier(year: year, month: monthZero + 1)
    }

    /// The ordered list of months to display.
    static func monthsToDisplay(
        startingMonth: StartingMonth,
        count: Int,
        offset: Int,
        referenceDate: Date,
        calendar: Calendar
    ) -> [MonthIdentifier] {
        let base = baseMonth(
            startingMonth: startingMonth,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let shifted = shift(base, by: offset)
        return (0..<max(0, count)).map { shift(shifted, by: $0) }
    }

    /// The localized full month name, e.g. "June" / "Juni".
    static func monthName(_ month: MonthIdentifier, calendar: Calendar) -> String {
        let symbols = calendar.monthSymbols // 0-based, Jan = index 0
        let index = month.month - 1
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    /// A localized "month + year" title whose word order follows the locale,
    /// e.g. "June 2026" (en) or "Juni 2026" (de).
    static func monthTitle(_ month: MonthIdentifier, calendar: Calendar) -> String {
        var comps = DateComponents()
        comps.year = month.year
        comps.month = month.month
        comps.day = 1
        guard let date = calendar.date(from: comps) else {
            return "\(monthName(month, calendar: calendar)) \(month.year)"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .autoupdatingCurrent
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    /// Weekday header symbols ordered to match the configured week start,
    /// e.g. ["Mon","Tue",...] or ["Sun","Mon",...]. Uses very-short symbols.
    static func weekdayHeaders(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols // index 0 = Sunday
        let first = calendar.firstWeekday - 1 // 0-based
        return (0..<7).map { symbols[(first + $0) % 7] }
    }

    /// The weekday (1 = Sun ... 7 = Sat) for a given column index, honoring the
    /// configured first weekday.
    static func weekday(forColumn column: Int, calendar: Calendar) -> Int {
        // firstWeekday is 1...7. Column 0 maps to firstWeekday.
        return ((calendar.firstWeekday - 1 + column) % 7) + 1
    }

    /// Builds the grid of day cells for a month as rows of 7 columns each.
    /// Leading and trailing cells are padded with `day == nil`.
    static func grid(
        for month: MonthIdentifier,
        referenceDate: Date,
        calendar: Calendar,
        holidayDays: Set<Int> = [],
        showAdjacentDays: Bool = true
    ) -> [[DayCell]] {
        var comps = DateComponents()
        comps.year = month.year
        comps.month = month.month
        comps.day = 1
        guard
            let firstOfMonth = calendar.date(from: comps),
            let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else {
            return []
        }

        let daysInMonth = range.count
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) // 1...7
        // Number of blank cells before day 1.
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        let todayComps = calendar.dateComponents([.year, .month, .day], from: referenceDate)

        var cells: [DayCell] = []
        cells.reserveCapacity(leadingBlanks + daysInMonth)

        // Leading slots: fill with the previous month's trailing days, or leave
        // blank when adjacent-day display is disabled.
        if leadingBlanks > 0 {
            let prev = shift(month, by: -1)
            let daysInPrev = daysIn(prev, calendar: calendar)
            let startDay = daysInPrev - leadingBlanks + 1
            for index in 0..<leadingBlanks {
                let weekday = weekday(forColumn: index, calendar: calendar)
                cells.append(DayCell(
                    day: nil,
                    adjacentDay: showAdjacentDays ? startDay + index : nil,
                    weekday: weekday,
                    isToday: false
                ))
            }
        }

        for day in 1...daysInMonth {
            let column = (leadingBlanks + (day - 1)) % 7
            let weekday = weekday(forColumn: column, calendar: calendar)
            let isToday = todayComps.year == month.year
                && todayComps.month == month.month
                && todayComps.day == day
            cells.append(DayCell(
                day: day,
                weekday: weekday,
                isToday: isToday,
                isHoliday: holidayDays.contains(day)
            ))
        }

        // Trailing slots: fill with the next month's leading days, or leave
        // blank when adjacent-day display is disabled.
        var nextDay = 1
        while cells.count % 7 != 0 {
            let column = cells.count % 7
            let weekday = weekday(forColumn: column, calendar: calendar)
            cells.append(DayCell(
                day: nil,
                adjacentDay: showAdjacentDays ? nextDay : nil,
                weekday: weekday,
                isToday: false
            ))
            nextDay += 1
        }

        // Chunk into rows of 7.
        return stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<min($0 + 7, cells.count)])
        }
    }

    /// Number of days in the given month.
    private static func daysIn(_ month: MonthIdentifier, calendar: Calendar) -> Int {
        var comps = DateComponents()
        comps.year = month.year
        comps.month = month.month
        comps.day = 1
        guard
            let firstOfMonth = calendar.date(from: comps),
            let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else {
            return 30
        }
        return range.count
    }
}
