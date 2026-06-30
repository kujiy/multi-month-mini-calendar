import SwiftUI

/// The main content shown when the menu bar item is clicked.
struct PopoverView: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var holidays: HolidayProvider

    /// Invoked when the gear button is tapped; presents the Settings window.
    let openSettings: () -> Void

    /// Navigation offset in months from the base month. Reset by "Today".
    @State private var monthOffset = 0

    /// Re-evaluated whenever the view rebuilds; "today" for highlighting.
    private var now: Date { Date() }

    private var calendar: Calendar {
        CalendarMath.calendar(weekStart: prefs.weekStart)
    }

    private var months: [MonthIdentifier] {
        CalendarMath.monthsToDisplay(
            startingMonth: prefs.startingMonth,
            count: prefs.numberOfMonths.rawValue,
            offset: monthOffset,
            referenceDate: now,
            calendar: calendar
        )
    }

    private var columnCount: Int {
        prefs.effectiveColumns(forMonths: prefs.numberOfMonths.rawValue)
    }

    /// Months chunked into rows of `columnCount` each.
    private var monthRows: [[MonthIdentifier]] {
        let all = months
        return stride(from: 0, to: all.count, by: columnCount).map {
            Array(all[$0..<min($0 + columnCount, all.count)])
        }
    }

    /// Explicit content width = N months + the gaps between them. Driving the
    /// frame from this (rather than intrinsic sizing) makes the popover resize
    /// exactly with the column count and removes leftover whitespace when
    /// switching from a wider layout back to a narrower one.
    private var contentWidth: CGFloat {
        let cols = CGFloat(columnCount)
        return cols * CalendarStyle.monthWidth + max(0, cols - 1) * CalendarStyle.monthSpacing
    }

    /// Holiday days for a month, or empty when the feature is disabled.
    private func holidayDays(for month: MonthIdentifier) -> Set<Int> {
        guard prefs.showHolidays else { return [] }
        return holidays.holidayDays(year: month.year, month: month.month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolbar

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(monthRows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: CalendarStyle.monthSpacing) {
                        ForEach(row, id: \.self) { month in
                            MonthView(
                                month: month,
                                calendar: calendar,
                                referenceDate: now,
                                holidayDays: holidayDays(for: month)
                            )
                        }
                    }
                }
            }
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(14)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                monthOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("Previous month")

            Button {
                monthOffset += 1
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .help("Next month")

            Button("Today") {
                monthOffset = 0
            }
            .buttonStyle(.borderless)
            .disabled(monthOffset == 0)
            .help("Return to the current month")

            Spacer()

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Preferences")
        }
        .font(.system(size: 13, weight: .medium))
    }
}
