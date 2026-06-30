# Multi-Month Mini Calendar

A lightweight, fast **read-only** calendar that lets you view multiple months at once from the macOS menu bar.
It does no schedule management at all — it is focused solely on "seeing dates".

## Features

- 🗓 **Multi-month view** — show 1 / 2 / 3 / 6 / 12 months at once
- 🧩 **Layout** — Vertical / Horizontal / Grid (1–4 columns)
- 📍 **Starting month** — from the current month / from January every year (yearly calendar)
- ◀▶ **Month navigation** and **Today** to jump back to the current month
- 🔴 Sundays in red, 🔵 Saturdays in blue, today highlighted with the accent color
- 📅 Toggle between Monday / Sunday week start
- 🎌 **Holiday display** — automatically detects the target country from macOS region settings and shows holidays in red (offline, 150+ countries)
- 🚫 No Dock icon, no network, no permission requests, read-only (clicking a date does nothing)

## Requirements

- macOS 15 or later (Apple Silicon / Intel)

## Install (download)

1. Download `Multi-Month-Mini-Calendar.zip` from the [latest release](https://github.com/kujiy/multi-month-mini-calendar/releases/latest).
2. Unzip it and move **Multi-Month Mini Calendar.app** to `/Applications`.
3. The app is ad-hoc signed (not notarized), so macOS Gatekeeper blocks it on first launch. Open it once with either method:
   - **Right-click the app → Open → Open**, or
   - run this in Terminal to clear the quarantine flag:
     ```bash
     xattr -dr com.apple.quarantine "/Applications/Multi-Month Mini Calendar.app"
     ```

After the first launch it opens normally by double-clicking.

## Build and Run

### Use as an app (recommended)

```bash
./build-app.sh
open "build/Multi-Month Mini Calendar.app"
```

A 📅 icon appears in the menu bar. Click it to open the calendar; click outside to close it.
Use the gear icon for settings and the power icon to quit.

### During development

```bash
swift build          # build
swift test           # unit tests (calendar calculation logic)
swift run            # launch directly (menu-bar resident)
```

## Settings

| Setting | Default | Options |
|---------|---------|---------|
| Number of Months | 2 | 1 / 2 / 3 / 6 / 12 |
| Layout | Vertical | Vertical / Horizontal / Grid |
| Grid Columns | 1 | 1–4 (only effective with Grid) |
| Starting Month | Current Month | Current Month / January |
| Week Start | Sunday | Monday / Sunday |
| Show Holidays | On | On / Off |

The target country for holidays is **automatically detected from the macOS "Language & Region" settings** (there is no manual selection).
The detected region is shown in the settings screen.

Settings are saved to `UserDefaults` and restored on the next launch.

## Structure

```
Sources/MultiMonthMiniCalendar/
  App.swift            # @main / NSStatusItem + NSPopover / hides the Dock icon
  HolidayProvider.swift# region auto-detection + offline loading of holiday data
  Preferences.swift    # settings model (UserDefaults persistence)
  CalendarMath.swift   # date calculations (pure logic, UI-independent)
  MonthView.swift      # rendering of a single month
  PopoverView.swift    # popover body (month navigation / layout)
  PreferencesView.swift# settings screen
  Holidays/<CC>.json   # bundled holiday data (per country, offline)
Tests/                 # unit tests for CalendarMath / HolidayProvider
Resources/Info.plist   # LSUIElement = true (menu-bar resident)
scripts/
  generate-holidays.swift  # holiday data generation tool (development only, requires network)
build-app.sh           # script to generate the .app bundle
```

The date calculation logic (`CalendarMath`) is a set of pure functions independent of the UI.
It receives the reference date and `Calendar` as arguments, so it can be tested deterministically.

## Holiday Data

Holiday data is sourced from **[Nager.Date](https://date.nager.at)**, and JSON built during development is
bundled into the app as `Sources/MultiMonthMiniCalendar/Holidays/<country code>.json`.
At runtime it uses no network and loads only the single auto-detected country offline.

- Coverage: years 2000–2050 / 150+ countries
- Includes **nationwide holidays only** (state/region-specific holidays are excluded)
- Nager.Date's code is MIT and its data is close to public domain, with no attribution display requirement

To update or extend the data (**network is used only during development, not at runtime**):

```bash
swift scripts/generate-holidays.swift   # regenerate Holidays/*.json
```

## License

The code for this app is [MIT License](LICENSE).
The holiday data is sourced from [Nager.Date](https://date.nager.at) (code MIT, data close to public domain with no attribution requirement).
