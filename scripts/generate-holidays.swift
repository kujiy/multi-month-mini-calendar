#!/usr/bin/env swift
//
// generate-holidays.swift — DEVELOPMENT-TIME TOOL (requires network).
//
// Fetches public-holiday data from the Nager.Date API for every supported
// country across a year range and writes one JSON file per country to
//   Sources/MultiMonthMiniCalendar/Holidays/<CC>.json
//
// The generated files are bundled into the app and read OFFLINE at runtime;
// this script is never shipped. Re-run it to refresh / extend the data:
//
//   swift scripts/generate-holidays.swift
//
// Only nationwide holidays are kept (global == true). Regional/sub-territory
// holidays (counties != nil) are excluded.
//
// Data source: https://date.nager.at  (code MIT; data is public-domain-like,
// no CC BY-SA attribution requirement).
//
import Foundation

let startYear = 2000
let endYear = 2050
let maxConcurrent = 8

let outputDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()          // scripts/
    .deletingLastPathComponent()          // repo root
    .appendingPathComponent("Sources/MultiMonthMiniCalendar/Holidays", isDirectory: true)

struct NagerHoliday: Decodable {
    let date: String
    let global: Bool
    let counties: [String]?
}

struct CountryFile: Encodable {
    let country: String
    let dates: [String]
}

let session = URLSession(configuration: .ephemeral)

/// Synchronous GET with a few retries (handles transient errors / 429).
func get(_ url: URL) -> Data? {
    for attempt in 0..<4 {
        let sem = DispatchSemaphore(value: 0)
        var result: Data?
        var status = 0
        let task = session.dataTask(with: url) { data, response, _ in
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
            result = data
            sem.signal()
        }
        task.resume()
        sem.wait()
        if status == 200, let result { return result }
        // Back off on rate limit / transient failure.
        usleep(useconds_t(200_000 * (attempt + 1)))
    }
    return nil
}

func fetchCountries() -> [String] {
    let url = URL(string: "https://date.nager.at/api/v3/AvailableCountries")!
    guard let data = get(url) else { return [] }
    struct C: Decodable { let countryCode: String }
    let list = (try? JSONDecoder().decode([C].self, from: data)) ?? []
    return list.map(\.countryCode).sorted()
}

func fetchCountry(_ code: String) -> CountryFile {
    var dates = Set<String>()
    for year in startYear...endYear {
        let url = URL(string: "https://date.nager.at/api/v3/PublicHolidays/\(year)/\(code)")!
        guard let data = get(url) else { continue }
        let holidays = (try? JSONDecoder().decode([NagerHoliday].self, from: data)) ?? []
        for h in holidays where h.global && (h.counties == nil) {
            dates.insert(h.date)
        }
    }
    return CountryFile(country: code, dates: dates.sorted())
}

func run() {
    try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

    let countries = fetchCountries()
    guard !countries.isEmpty else {
        FileHandle.standardError.write(Data("Failed to fetch country list.\n".utf8))
        exit(1)
    }
    print("Fetching \(countries.count) countries, years \(startYear)–\(endYear)…")

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    let group = DispatchGroup()
    let gate = DispatchSemaphore(value: maxConcurrent)
    let queue = DispatchQueue(label: "gen", attributes: .concurrent)
    let printLock = NSLock()
    var done = 0

    for code in countries {
        gate.wait()
        group.enter()
        queue.async {
            let file = fetchCountry(code)
            if let data = try? encoder.encode(file) {
                let out = outputDir.appendingPathComponent("\(code).json")
                try? data.write(to: out)
            }
            printLock.lock()
            done += 1
            print("[\(done)/\(countries.count)] \(code): \(file.dates.count) dates")
            printLock.unlock()
            gate.signal()
            group.leave()
        }
    }
    group.wait()
    print("Done → \(outputDir.path)")
}

run()
