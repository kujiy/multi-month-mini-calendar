import XCTest
@testable import MultiMonthMiniCalendar

@MainActor
final class HolidayProviderTests: XCTestCase {

    private func makeJPProvider() -> HolidayProvider {
        // Read the JP.json fixture bundled with the test target.
        HolidayProvider(regionCode: "JP", bundle: .module)
    }

    func testRegionDisplayName() {
        let provider = makeJPProvider()
        XCTAssertEqual(provider.regionCode, "JP")
        XCTAssertEqual(provider.regionDisplayName, "Japan")
    }

    func testHasDataForBundledCountry() {
        XCTAssertTrue(makeJPProvider().hasData)
    }

    func testKnownHolidaysAreReported() {
        let provider = makeJPProvider()
        let jan = provider.holidayDays(year: 2026, month: 1)
        XCTAssertTrue(jan.contains(1))   // New Year's Day
        XCTAssertTrue(jan.contains(12))  // Coming of Age Day
        XCTAssertFalse(jan.contains(2))  // ordinary weekday
    }

    func testHolidaysAreScopedToMonth() {
        let provider = makeJPProvider()
        let feb = provider.holidayDays(year: 2026, month: 2)
        XCTAssertEqual(feb, [11, 23])
        // January holidays must not leak into February.
        XCTAssertFalse(feb.contains(1))
    }

    func testUnknownRegionHasNoData() {
        let provider = HolidayProvider(regionCode: "ZZ", bundle: .module)
        XCTAssertFalse(provider.hasData)
        XCTAssertTrue(provider.holidayDays(year: 2026, month: 1).isEmpty)
    }

    func testNilRegionHasNoData() {
        let provider = HolidayProvider(regionCode: nil, bundle: .module)
        XCTAssertFalse(provider.hasData)
        XCTAssertNil(provider.regionDisplayName)
    }
}
