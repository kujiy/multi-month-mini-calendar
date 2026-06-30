import Foundation
import Combine

/// Loads bundled, offline public-holiday data for the region detected from the
/// system locale, and answers per-month holiday lookups.
///
/// Only the single detected country's JSON is decoded (lazily, on first use),
/// keeping memory minimal. Data is generated at development time by
/// `scripts/generate-holidays.swift` and shipped inside the app — no network or
/// permissions are used at runtime.
@MainActor
final class HolidayProvider: ObservableObject {
    static let shared = HolidayProvider()

    /// ISO 3166-1 region code from the system locale, e.g. "JP", "US".
    let regionCode: String?

    /// Localized region name for display, e.g. "Japan". `nil` if unknown.
    var regionDisplayName: String? {
        guard let regionCode else { return nil }
        return Locale.current.localizedString(forRegionCode: regionCode)
    }

    /// True when bundled holiday data exists for the detected region.
    var hasData: Bool {
        loadIfNeeded()
        return !byMonth.isEmpty
    }

    /// Lazily-decoded lookup: key = year * 100 + month → set of holiday days.
    private var byMonth: [Int: Set<Int>] = [:]
    private var loaded = false

    private let bundle: Bundle

    /// - Parameters:
    ///   - regionCode: override the detected region (tests). Defaults to the
    ///     system locale's region.
    ///   - bundle: resource bundle to read from (tests). Defaults to the
    ///     resolved resource bundle (see `Bundle.holidayResources`).
    init(regionCode: String? = Locale.current.region?.identifier, bundle: Bundle = .holidayResources) {
        self.regionCode = regionCode
        self.bundle = bundle
    }

    private struct CountryFile: Decodable {
        let country: String
        let dates: [String] // "yyyy-MM-dd"
    }

    /// Days of `month`/`year` that are public holidays in the detected region.
    /// Returns an empty set when there is no region or no bundled data.
    func holidayDays(year: Int, month: Int) -> Set<Int> {
        loadIfNeeded()
        return byMonth[year * 100 + month] ?? []
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        guard
            let regionCode,
            let url = bundle.url(
                forResource: regionCode,
                withExtension: "json",
                subdirectory: "Holidays"
            ),
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(CountryFile.self, from: data)
        else {
            return
        }

        for iso in file.dates {
            // Parse "yyyy-MM-dd" without a DateFormatter for speed/locale safety.
            let parts = iso.split(separator: "-")
            guard parts.count == 3,
                  let y = Int(parts[0]),
                  let m = Int(parts[1]),
                  let d = Int(parts[2])
            else { continue }
            byMonth[y * 100 + m, default: []].insert(d)
        }
    }
}

extension Bundle {
    /// The SwiftPM-generated resource bundle, located robustly.
    ///
    /// `Bundle.module`'s generated accessor only looks next to the main
    /// executable. That is correct for `swift run`, but once the binary is
    /// wrapped in a `.app`, `Bundle.main.bundleURL` points at the `.app` root —
    /// a location that cannot be code-signed (everything must live under
    /// `Contents/`). So we look in the standard, signable `Contents/Resources`
    /// first, then fall back to the locations `Bundle.module` would try.
    static let holidayResources: Bundle = {
        let bundleName = "MultiMonthMiniCalendar_MultiMonthMiniCalendar.bundle"
        let candidates = [
            Bundle.main.resourceURL,   // .app/Contents/Resources (signed apps)
            Bundle.main.bundleURL,     // exe dir for `swift run`, .app root otherwise
        ]
        for case let directory? in candidates {
            let url = directory.appendingPathComponent(bundleName)
            if let bundle = Bundle(url: url) { return bundle }
        }
        // Last resort: the generated accessor (handles tests / unusual layouts).
        return .module
    }()
}
