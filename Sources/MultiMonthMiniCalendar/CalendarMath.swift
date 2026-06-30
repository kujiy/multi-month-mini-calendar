import Foundation

/// A single month's identity (year + 1-based month).
struct MonthIdentifier: Equatable, Hashable {
    var year: Int
    var month: Int // 1...12
}

/// One day cell in a month grid. `day == nil` marks padding for days that
/// belong to an adjacent month and are rendered as blanks.
struct DayCell: Equatable {
    /// Day of month, or `nil` for leading/trailing padding.
    var day: Int?
    /// Weekday: 1 = Sunday ... 7 = Saturday (matches `Calendar` component).
    /// `nil` for padding cells.
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
        holidayDays: Set<Int> = []
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

        for _ in 0..<leadingBlanks {
            cells.append(DayCell(day: nil, weekday: nil, isToday: false))
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

        // Pad trailing to complete the final row.
        while cells.count % 7 != 0 {
            cells.append(DayCell(day: nil, weekday: nil, isToday: false))
        }

        // Chunk into rows of 7.
        return stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<min($0 + 7, cells.count)])
        }
    }
}
