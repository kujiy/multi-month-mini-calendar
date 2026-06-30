import SwiftUI

/// Visual constants shared across the calendar UI.
enum CalendarStyle {
    static let cellWidth: CGFloat = 26
    static let cellHeight: CGFloat = 20

    /// Intrinsic width of one month (7 day columns). Used to size the popover
    /// deterministically so it grows/shrinks exactly with the column count.
    static let monthWidth: CGFloat = cellWidth * 7

    /// Horizontal gap between adjacent months.
    static let monthSpacing: CGFloat = 20
    static let dayFont: Font = .system(size: 12, design: .rounded)
    static let headerFont: Font = .system(size: 11, weight: .semibold, design: .rounded)
    static let titleFont: Font = .system(size: 13, weight: .bold, design: .rounded)

    /// Weekend / weekday text color. 1 = Sunday (red), 7 = Saturday (blue).
    static func color(forWeekday weekday: Int?) -> Color {
        switch weekday {
        case 1: return .red
        case 7: return .blue
        default: return .primary
        }
    }
}

/// Renders a single month: title, weekday header row, and day grid.
/// Read-only — day cells are plain text with no interaction.
struct MonthView: View {
    let month: MonthIdentifier
    let calendar: Calendar
    let referenceDate: Date
    /// Days of this month that are public holidays (empty when disabled).
    var holidayDays: Set<Int> = []
    /// Whether to fill leading/trailing blanks with adjacent months' days.
    var showAdjacentMonthDays: Bool = true

    private var title: String {
        CalendarMath.monthTitle(month, calendar: calendar)
    }

    private var headers: [String] {
        CalendarMath.weekdayHeaders(calendar: calendar)
    }

    private var rows: [[DayCell]] {
        CalendarMath.grid(
            for: month,
            referenceDate: referenceDate,
            calendar: calendar,
            holidayDays: holidayDays,
            showAdjacentDays: showAdjacentMonthDays
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CalendarStyle.titleFont)
                .padding(.leading, 2)

            // Weekday header row.
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { index, symbol in
                    let weekday = CalendarMath.weekday(forColumn: index, calendar: calendar)
                    Text(symbol)
                        .font(CalendarStyle.headerFont)
                        .foregroundStyle(CalendarStyle.color(forWeekday: weekday).opacity(0.7))
                        .frame(width: CalendarStyle.cellWidth, height: CalendarStyle.cellHeight)
                }
            }

            // Day grid.
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        DayCellView(cell: cell)
                    }
                }
            }
        }
        .fixedSize()
    }
}

/// One day in the grid. Today is highlighted with an accent-colored disc.
private struct DayCellView: View {
    let cell: DayCell

    var body: some View {
        ZStack {
            if cell.isToday {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: CalendarStyle.cellHeight, height: CalendarStyle.cellHeight)
            }
            if let day = cell.day {
                Text("\(day)")
                    .font(CalendarStyle.dayFont)
                    .foregroundStyle(textColor)
            } else if let adjacentDay = cell.adjacentDay {
                // Previous/next month spill-over, shown faintly.
                Text("\(adjacentDay)")
                    .font(CalendarStyle.dayFont)
                    .foregroundStyle(CalendarStyle.color(forWeekday: cell.weekday).opacity(0.3))
            }
        }
        .frame(width: CalendarStyle.cellWidth, height: CalendarStyle.cellHeight)
    }

    private var textColor: Color {
        if cell.isToday {
            return .white
        }
        // Holidays are shown in red, matching Sundays, regardless of weekday.
        if cell.isHoliday {
            return .red
        }
        return CalendarStyle.color(forWeekday: cell.weekday)
    }
}
