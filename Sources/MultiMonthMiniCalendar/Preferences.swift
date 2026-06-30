import SwiftUI
import Combine

/// How many months are displayed at once.
enum MonthCount: Int, CaseIterable, Identifiable {
    case one = 1
    case two = 2
    case three = 3
    case six = 6
    case twelve = 12

    var id: Int { rawValue }
    var label: String { "\(rawValue)" }
}

/// Arrangement of the displayed months.
enum CalendarLayout: String, CaseIterable, Identifiable {
    case vertical
    case horizontal
    case grid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vertical: return "Vertical"
        case .horizontal: return "Horizontal"
        case .grid: return "Grid"
        }
    }
}

/// Where the displayed range begins.
enum StartingMonth: String, CaseIterable, Identifiable {
    case currentMonth
    case january

    var id: String { rawValue }

    var label: String {
        switch self {
        case .currentMonth: return "Current Month"
        case .january: return "January"
        }
    }
}

/// First day of the week.
enum WeekStart: String, CaseIterable, Identifiable {
    case monday
    case sunday

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monday: return "Monday"
        case .sunday: return "Sunday"
        }
    }

    /// `Calendar.firstWeekday` value (1 = Sunday, 2 = Monday).
    var firstWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        }
    }
}

/// User preferences, persisted to `UserDefaults`.
///
/// Backed by a small manual wrapper rather than `@AppStorage` so the same
/// store can be exercised from unit tests with an injected `UserDefaults`.
@MainActor
final class Preferences: ObservableObject {
    private enum Key {
        static let numberOfMonths = "numberOfMonths"
        static let layout = "layout"
        static let gridColumns = "gridColumns"
        static let startingMonth = "startingMonth"
        static let weekStart = "weekStart"
        static let showHolidays = "showHolidays"
    }

    /// Shared instance used by both the menu-bar popover and the Settings
    /// window so changes in one are immediately reflected in the other.
    static let shared = Preferences()

    private let defaults: UserDefaults

    @Published var numberOfMonths: MonthCount {
        didSet { defaults.set(numberOfMonths.rawValue, forKey: Key.numberOfMonths) }
    }

    @Published var layout: CalendarLayout {
        didSet { defaults.set(layout.rawValue, forKey: Key.layout) }
    }

    /// Number of columns when `layout == .grid`. Clamped to 1...4.
    @Published var gridColumns: Int {
        didSet {
            let clamped = min(4, max(1, gridColumns))
            if clamped != gridColumns {
                gridColumns = clamped
                return
            }
            defaults.set(gridColumns, forKey: Key.gridColumns)
        }
    }

    @Published var startingMonth: StartingMonth {
        didSet { defaults.set(startingMonth.rawValue, forKey: Key.startingMonth) }
    }

    @Published var weekStart: WeekStart {
        didSet { defaults.set(weekStart.rawValue, forKey: Key.weekStart) }
    }

    /// Whether public holidays are highlighted (in red) for the detected region.
    @Published var showHolidays: Bool {
        didSet { defaults.set(showHolidays, forKey: Key.showHolidays) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let monthsRaw = defaults.object(forKey: Key.numberOfMonths) as? Int
        self.numberOfMonths = monthsRaw.flatMap(MonthCount.init(rawValue:)) ?? .two

        let layoutRaw = defaults.string(forKey: Key.layout)
        self.layout = layoutRaw.flatMap(CalendarLayout.init(rawValue:)) ?? .vertical

        let columns = defaults.object(forKey: Key.gridColumns) as? Int ?? 1
        self.gridColumns = min(4, max(1, columns))

        let startRaw = defaults.string(forKey: Key.startingMonth)
        self.startingMonth = startRaw.flatMap(StartingMonth.init(rawValue:)) ?? .currentMonth

        let weekRaw = defaults.string(forKey: Key.weekStart)
        self.weekStart = weekRaw.flatMap(WeekStart.init(rawValue:)) ?? .sunday

        self.showHolidays = defaults.object(forKey: Key.showHolidays) as? Bool ?? true
    }

    /// Effective number of columns used to lay out the month tiles, derived
    /// from the layout choice. Vertical = single column; Horizontal = one row
    /// (all months side by side); Grid = the user's chosen column count.
    func effectiveColumns(forMonths count: Int) -> Int {
        switch layout {
        case .vertical:
            return 1
        case .horizontal:
            return max(1, count)
        case .grid:
            return min(gridColumns, max(1, count))
        }
    }
}
