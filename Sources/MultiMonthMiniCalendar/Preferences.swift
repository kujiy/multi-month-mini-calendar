import SwiftUI
import Combine
import ServiceManagement
import OSLog

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
    case previousMonth
    case january

    var id: String { rawValue }

    var label: String {
        switch self {
        case .currentMonth: return "Current Month"
        case .previousMonth: return "Last Month"
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
        static let showAdjacentMonthDays = "showAdjacentMonthDays"
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

    /// Whether the leading/trailing blanks show the adjacent month's days faintly.
    @Published var showAdjacentMonthDays: Bool {
        didSet { defaults.set(showAdjacentMonthDays, forKey: Key.showAdjacentMonthDays) }
    }

    /// Whether the app launches automatically when the user logs in.
    ///
    /// Unlike the other preferences, the source of truth is the system login-item
    /// registry (`SMAppService`), not `UserDefaults`: macOS owns this state and the
    /// user can change it from System Settings. The `didSet` registers/unregisters
    /// the main app accordingly, reverting the published value if the system call
    /// fails (e.g. when running unbundled via `swift run`).
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            let service = SMAppService.mainApp
            do {
                if launchAtLogin {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                Self.log.error("Failed to update launch-at-login: \(error.localizedDescription, privacy: .public)")
                launchAtLogin = oldValue
            }
        }
    }

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MultiMonthMiniCalendar",
        category: "Preferences"
    )

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let monthsRaw = defaults.object(forKey: Key.numberOfMonths) as? Int
        self.numberOfMonths = monthsRaw.flatMap(MonthCount.init(rawValue:)) ?? .three

        let layoutRaw = defaults.string(forKey: Key.layout)
        self.layout = layoutRaw.flatMap(CalendarLayout.init(rawValue:)) ?? .vertical

        let columns = defaults.object(forKey: Key.gridColumns) as? Int ?? 1
        self.gridColumns = min(4, max(1, columns))

        let startRaw = defaults.string(forKey: Key.startingMonth)
        self.startingMonth = startRaw.flatMap(StartingMonth.init(rawValue:)) ?? .previousMonth

        let weekRaw = defaults.string(forKey: Key.weekStart)
        self.weekStart = weekRaw.flatMap(WeekStart.init(rawValue:)) ?? .sunday

        self.showHolidays = defaults.object(forKey: Key.showHolidays) as? Bool ?? true

        self.showAdjacentMonthDays = defaults.object(forKey: Key.showAdjacentMonthDays) as? Bool ?? true

        // Reflect the current system login-item state rather than a stored value.
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// The starting month actually used for display. In 1-month view the
    /// calendar always anchors on the current month — "Last Month" and
    /// "January" would each show a single non-current month, which is rarely
    /// what's wanted — so those choices are ignored (and disabled in the UI)
    /// while the user's stored preference is preserved for multi-month views.
    var effectiveStartingMonth: StartingMonth {
        numberOfMonths == .one ? .currentMonth : startingMonth
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
