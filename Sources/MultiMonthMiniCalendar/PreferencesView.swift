import SwiftUI

/// The Preferences (Settings) window.
struct PreferencesView: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var holidays: HolidayProvider = .shared

    private var regionLabel: String {
        if let name = holidays.regionDisplayName {
            return holidays.hasData ? "\(name) (auto)" : "\(name) (no data)"
        }
        return "—"
    }

    var body: some View {
        Form {
            Picker("Number of Months", selection: $prefs.numberOfMonths) {
                ForEach(MonthCount.allCases) { count in
                    Text(count.label).tag(count)
                }
            }

            Picker("Layout", selection: $prefs.layout) {
                ForEach(CalendarLayout.allCases) { layout in
                    Text(layout.label).tag(layout)
                }
            }
            .pickerStyle(.segmented)

            Picker("Grid Columns", selection: $prefs.gridColumns) {
                ForEach(1...4, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .disabled(prefs.layout != .grid)
            .help("Only applies when Layout is Grid.")

            Picker("Starting Month", selection: $prefs.startingMonth) {
                ForEach(StartingMonth.allCases) { start in
                    Text(start.label).tag(start)
                }
            }

            Picker("Week Start", selection: $prefs.weekStart) {
                ForEach(WeekStart.allCases) { start in
                    Text(start.label).tag(start)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Show Holidays", isOn: $prefs.showHolidays)

            LabeledContent("Region", value: regionLabel)
                .help("Detected automatically from your macOS Language & Region settings.")

            Section {
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .help("Quit MultiMonthMiniCalendar")
            }
        }
        .formStyle(.grouped)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
    }
}
