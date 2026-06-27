import Foundation

/// Result of a sunrise/sunset computation.
enum SolarEvent: Equatable {
    /// The sunrise or sunset instant (an absolute point in time).
    case event(Date)
    /// Polar region: on this date at this location the sun never crosses the
    /// horizon (24-hour day or 24-hour night), so there is no rise/set event.
    case noEvent
}

/// Pure sunrise/sunset calculator — no CoreLocation, no network, deterministic.
///
/// Implements the NOAA solar-position algorithm (the "NOAA_Global" spreadsheet,
/// after Meeus, *Astronomical Algorithms*). Inputs are a latitude, longitude,
/// and a date; the civil date is read in the supplied `timeZone` and the result
/// is returned as an absolute `Date` (which the caller can render in any zone).
///
/// Reference: https://gml.noaa.gov/grad/solcalc/calcdetails.html
/// Accuracy: within ~1 minute for latitudes inside ±72°.
protocol SolarCalculating {
    func sunrise(lat: Double, long: Double, date: Date, in timeZone: TimeZone) -> SolarEvent
    func sunset(lat: Double, long: Double, date: Date, in timeZone: TimeZone) -> SolarEvent
}

struct SolarCalculator: SolarCalculating {
    /// Zenith for the geometric horizon including atmospheric refraction
    /// (−34′) and the sun's apparent radius (−16′): 90° 50′ = 90.833°.
    private static let sunriseZenith = 90.833

    func sunrise(lat: Double, long: Double, date: Date, in timeZone: TimeZone) -> SolarEvent {
        compute(lat: lat, long: long, date: date, timeZone: timeZone, isSunrise: true)
    }

    func sunset(lat: Double, long: Double, date: Date, in timeZone: TimeZone) -> SolarEvent {
        compute(lat: lat, long: long, date: date, timeZone: timeZone, isSunrise: false)
    }

    // MARK: - Core algorithm

    private func compute(
        lat: Double,
        long: Double,
        date: Date,
        timeZone: TimeZone,
        isSunrise: Bool
    ) -> SolarEvent {
        // The civil date is interpreted in the requested time zone.
        var civilCalendar = Calendar(identifier: .gregorian)
        civilCalendar.timeZone = timeZone
        let civil = civilCalendar.dateComponents([.year, .month, .day], from: date)
        guard let year = civil.year, let month = civil.month, let day = civil.day else {
            return .noEvent
        }

        // Julian Day at 12:00 UT for the civil date. Solar declination and the
        // equation of time vary slowly, so evaluating them at local noon is
        // accurate to well under a minute for rise/set.
        let jd = julianDayNoon(year: year, month: month, day: day)
        let t = (jd - 2451545.0) / 36525.0 // Julian centuries since J2000.0

        // Geometric mean longitude and anomaly of the sun (degrees).
        let l0 = normalizeDegrees(280.46646 + t * (36000.76983 + t * 0.0003032))
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        // Eccentricity of Earth's orbit (dimensionless).
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let mRad = deg2rad(m)
        // Sun's equation of center.
        let c = sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * mRad) * (0.019993 - 0.000101 * t)
            + sin(3 * mRad) * 0.000289

        let trueLong = l0 + c
        let omega = 125.04 - 1934.136 * t
        let appLong = trueLong - 0.00569 - 0.00478 * sin(deg2rad(omega))

        // Obliquity of the ecliptic, with the standard nutation correction.
        let meanObliq = 23.0 + (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0
        let obliqCorr = meanObliq + 0.00256 * cos(deg2rad(omega))

        // Solar declination (degrees).
        let decl = rad2deg(asin(sin(deg2rad(obliqCorr)) * sin(deg2rad(appLong))))

        // Equation of time (minutes).
        let y = pow(tan(deg2rad(obliqCorr / 2.0)), 2)
        let l0Rad = deg2rad(l0)
        let eqTime = 4.0 * rad2deg(
            y * sin(2 * l0Rad)
            - 2 * e * sin(mRad)
            + 4 * e * y * sin(mRad) * cos(2 * l0Rad)
            - 0.5 * y * y * sin(4 * l0Rad)
            - 1.25 * e * e * sin(2 * mRad)
        )

        // Hour angle of sunrise/sunset (degrees). Out-of-range cosine ⇒ the sun
        // never reaches the horizon on this date — a polar day or night.
        let latRad = deg2rad(lat)
        let declRad = deg2rad(decl)
        let cosH = cos(deg2rad(Self.sunriseZenith)) / (cos(latRad) * cos(declRad)) - tan(latRad) * tan(declRad)
        guard cosH >= -1.0, cosH <= 1.0 else {
            return .noEvent
        }
        let hourAngle = rad2deg(acos(cosH))

        // Minutes after 00:00 UTC of the civil date. The sunrise hour angle is
        // taken west (later in the morning ⇒ earlier instant), hence the sign.
        let solarNoonUTC = 720.0 - 4.0 * long - eqTime
        let minutesUTC = isSunrise
            ? solarNoonUTC - 4.0 * hourAngle
            : solarNoonUTC + 4.0 * hourAngle

        guard let utcMidnight = utcMidnight(year: year, month: month, day: day) else {
            return .noEvent
        }
        // Adding a possibly-negative / >1440 offset naturally rolls the instant
        // into the adjacent UTC day (e.g. Tokyo sunrise lands on the prior UTC day).
        return .event(utcMidnight.addingTimeInterval(minutesUTC * 60.0))
    }

    // MARK: - Helpers

    /// Julian Day Number at 12:00 UT for a proleptic-Gregorian calendar date.
    private func julianDayNoon(year: Int, month: Int, day: Int) -> Double {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        let jdn = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
        return Double(jdn)
    }

    private func utcMidnight(year: Int, month: Int, day: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    private func deg2rad(_ degrees: Double) -> Double { degrees * .pi / 180.0 }
    private func rad2deg(_ radians: Double) -> Double { radians * 180.0 / .pi }

    private func normalizeDegrees(_ angle: Double) -> Double {
        let r = angle.truncatingRemainder(dividingBy: 360.0)
        return r < 0 ? r + 360.0 : r
    }
}
