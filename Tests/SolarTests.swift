import XCTest
@testable import Paperweight

/// Golden values come from the independent sunrise-sunset.org API (which itself
/// follows the NOAA/Meeus algorithm). NOAA accuracy is ~±1 min within ±72° and
/// the two implementations differ by under 2 min, so we assert a ±3-minute
/// tolerance. Verified 2026-06-27.
final class SolarTests: XCTestCase {
    private let solar = SolarCalculator()
    private let utc = TimeZone(identifier: "UTC")!

    /// Tolerance for golden comparisons.
    private let toleranceSeconds: TimeInterval = 3 * 60

    // MARK: - Helpers

    /// Noon on the given civil date in `timeZone` — a stable instant from which
    /// the calculator reads only the year/month/day.
    private func date(_ year: Int, _ month: Int, _ day: Int, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        components.hour = 12
        return calendar.date(from: components)!
    }

    private func iso(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string)!
    }

    private func assertEvent(
        _ event: SolarEvent,
        matches expectedISO: String,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .event(actual) = event else {
            return XCTFail("\(label): expected an event, got noEvent", file: file, line: line)
        }
        let expected = iso(expectedISO)
        let deltaSeconds = abs(actual.timeIntervalSince(expected))
        XCTAssertLessThanOrEqual(
            deltaSeconds, toleranceSeconds,
            "\(label): \(actual) vs expected \(expected) (Δ \(Int(deltaSeconds / 60))m)",
            file: file, line: line
        )
    }

    // MARK: - Golden rise/set values

    func testNewYorkSummerSolstice() {
        // New York City, 2024-06-21. Sunset rolls into the next UTC day.
        let d = date(2024, 6, 21, in: utc)
        assertEvent(solar.sunrise(lat: 40.7128, long: -74.0060, date: d, in: utc),
                    matches: "2024-06-21T09:23:33Z", "NYC sunrise")
        assertEvent(solar.sunset(lat: 40.7128, long: -74.0060, date: d, in: utc),
                    matches: "2024-06-22T00:32:25Z", "NYC sunset")
    }

    func testEquatorMarchEquinox() {
        // Equator at the Greenwich meridian, 2024-03-20.
        let d = date(2024, 3, 20, in: utc)
        assertEvent(solar.sunrise(lat: 0, long: 0, date: d, in: utc),
                    matches: "2024-03-20T06:02:54Z", "Equator sunrise")
        assertEvent(solar.sunset(lat: 0, long: 0, date: d, in: utc),
                    matches: "2024-03-20T18:11:43Z", "Equator sunset")
    }

    func testTokyoWinterSolsticeLocalDate() {
        // Tokyo, civil date 2024-12-21 (JST). Sunrise lands on the prior UTC day,
        // which exercises the civil-date-in-timezone handling.
        let jst = TimeZone(identifier: "Asia/Tokyo")!
        let d = date(2024, 12, 21, in: jst)
        assertEvent(solar.sunrise(lat: 35.6895, long: 139.6917, date: d, in: jst),
                    matches: "2024-12-20T21:45:42Z", "Tokyo sunrise")
        assertEvent(solar.sunset(lat: 35.6895, long: 139.6917, date: d, in: jst),
                    matches: "2024-12-21T07:32:59Z", "Tokyo sunset")
    }

    // MARK: - Polar sentinel

    func testPolarDayReturnsNoEvent() {
        // Longyearbyen, Svalbard (78.22°N) at the June solstice: 24-hour daylight.
        let d = date(2024, 6, 21, in: utc)
        XCTAssertEqual(solar.sunrise(lat: 78.22, long: 15.65, date: d, in: utc), .noEvent)
        XCTAssertEqual(solar.sunset(lat: 78.22, long: 15.65, date: d, in: utc), .noEvent)
    }

    func testPolarNightReturnsNoEvent() {
        // Longyearbyen at the December solstice: 24-hour darkness.
        let d = date(2024, 12, 21, in: utc)
        XCTAssertEqual(solar.sunrise(lat: 78.22, long: 15.65, date: d, in: utc), .noEvent)
        XCTAssertEqual(solar.sunset(lat: 78.22, long: 15.65, date: d, in: utc), .noEvent)
    }

    func testSouthernPolarDayReturnsNoEvent() {
        // McMurdo, Antarctica (77.85°S) at the December solstice: 24-hour daylight.
        let d = date(2024, 12, 21, in: utc)
        XCTAssertEqual(solar.sunset(lat: -77.85, long: 166.67, date: d, in: utc), .noEvent)
    }

    // MARK: - Equinox day length

    func testEquinoxDayLengthIsRoughlyTwelveHours() {
        // At the equator on the equinox, day length ≈ 12 h (geometric horizon plus
        // refraction make it a few minutes longer).
        let d = date(2024, 3, 20, in: utc)
        guard case let .event(sunrise) = solar.sunrise(lat: 0, long: 0, date: d, in: utc),
              case let .event(sunset) = solar.sunset(lat: 0, long: 0, date: d, in: utc) else {
            return XCTFail("Expected both sunrise and sunset at the equator on the equinox")
        }
        let dayLengthMinutes = sunset.timeIntervalSince(sunrise) / 60.0
        XCTAssertEqual(dayLengthMinutes, 720, accuracy: 15)
    }

    // MARK: - Sentinel equality

    func testSolarEventEquality() {
        let date1 = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(SolarEvent.event(date1), SolarEvent.event(date1))
        XCTAssertEqual(SolarEvent.noEvent, SolarEvent.noEvent)
        XCTAssertNotEqual(SolarEvent.event(date1), SolarEvent.noEvent)
    }
}
