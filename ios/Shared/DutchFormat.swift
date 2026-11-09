import Foundation

enum DutchFormat {
    static let timeZone = TimeZone(identifier: "Europe/Amsterdam")!
    static let locale = Locale(identifier: "nl_NL")

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        return calendar
    }()

    private static func verbatim(_ format: Date.FormatString) -> Date.VerbatimFormatStyle {
        Date.VerbatimFormatStyle(format: format, locale: locale, timeZone: timeZone, calendar: calendar)
    }

    private static let longStyle = verbatim(
        "\(weekday: .wide) \(day: .defaultDigits) \(month: .wide) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)"
    )
    private static let compactStyle = verbatim(
        "\(weekday: .abbreviated) \(day: .defaultDigits) \(month: .abbreviated) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)"
    )
    private static let weekdayStyle = verbatim("\(weekday: .abbreviated)")
    private static let clockStyle = verbatim(
        "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)"
    )

    static func long(_ date: Date) -> String {
        date.formatted(longStyle)
    }

    static func compact(_ date: Date) -> String {
        date.formatted(compactStyle).replacingOccurrences(of: ".", with: "").capitalizedFirst
    }

    static func weekdayShort(_ date: Date) -> String {
        date.formatted(weekdayStyle).replacingOccurrences(of: ".", with: "")
    }

    static func clock(_ date: Date) -> String {
        date.formatted(clockStyle)
    }

    private static let dayLongStyle = verbatim("\(weekday: .wide) \(day: .defaultDigits) \(month: .wide)")
    private static let dayCompactStyle = verbatim("\(weekday: .abbreviated) \(day: .defaultDigits) \(month: .abbreviated)")
    private static let monthStyle = verbatim("\(month: .wide) \(year: .defaultDigits)")
    private static let monthShortStyle = verbatim("\(month: .abbreviated)")

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func addingDays(_ days: Int, to day: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: day) ?? day
    }

    static func day(fromISO raw: String) -> Date? {
        let parts = raw.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func isoDay(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func year(_ date: Date) -> Int {
        calendar.component(.year, from: date)
    }

    private static func withYear(_ label: String, of date: Date, now: Date) -> String {
        year(date) == year(now) ? label : "\(label) \(year(date))"
    }

    static func dayLong(_ date: Date, now: Date) -> String {
        withYear(date.formatted(dayLongStyle), of: date, now: now)
    }

    static func dayCompact(_ date: Date, now: Date) -> String {
        withYear(date.formatted(dayCompactStyle).replacingOccurrences(of: ".", with: "").capitalizedFirst, of: date, now: now)
    }

    static func dayShort(_ date: Date, now: Date) -> String {
        withYear("\(calendar.component(.day, from: date)) \(monthShort(date).lowercased())", of: date, now: now)
    }

    static func monthTitle(_ date: Date) -> String {
        date.formatted(monthStyle).capitalizedFirst
    }

    static func monthShort(_ date: Date) -> String {
        date.formatted(monthShortStyle).replacingOccurrences(of: ".", with: "").uppercased()
    }

    static func dayRelative(_ day: Date, now: Date) -> String {
        let today = startOfDay(now)
        let target = startOfDay(day)
        let days = calendar.dateComponents([.day], from: target, to: today).day ?? 0
        switch days {
        case ...0: return "vandaag"
        case 1: return "gisteren"
        case 2..<14: return "\(days)\u{00A0}dagen geleden"
        case 14..<63: return "\(Int((Double(days) / 7).rounded()))\u{00A0}weken geleden"
        default:
            let months = calendar.dateComponents([.month], from: target, to: today).month ?? 0
            if months < 24 { return "\(max(months, 2))\u{00A0}maanden geleden" }
            return "\(months / 12)\u{00A0}jaar geleden"
        }
    }

    static func amsterdamHour(_ date: Date) -> Int {
        calendar.component(.hour, from: date)
    }

    static func relative(hour: Date, now: Date) -> String {
        let delta = now.flooredToHour.hours(until: hour.flooredToHour)
        if delta == 0 { return "nu" }
        let magnitude = abs(delta)
        if magnitude < 36 {
            return delta < 0 ? "\(magnitude)\u{00A0}uur geleden" : "over \(magnitude)\u{00A0}uur"
        }
        if delta < 0 {
            return dayRelative(hour, now: now)
        }
        return "over \(Int((Double(magnitude) / 24).rounded()))\u{00A0}dagen"
    }

    static func gigawattHours(_ kWh: Double) -> String {
        let gwh = kWh / 1_000_000
        let oneDecimal = (gwh * 10).rounded() / 10
        if oneDecimal >= 10 {
            return "\(number(gwh, fractionDigits: 0))\u{00A0}GWh"
        }
        return "\(number(gwh, fractionDigits: 1))\u{00A0}GWh"
    }

    static func gigawattHoursSpoken(_ kWh: Double) -> String {
        gigawattHours(kWh).replacingOccurrences(of: "GWh", with: "gigawattuur")
    }

    static func megawattHours(_ kWh: Double) -> String {
        "\(number(kWh / 1000, fractionDigits: 0))\u{00A0}MWh"
    }

    static func megawattHoursSpoken(_ kWh: Double) -> String {
        megawattHours(kWh).replacingOccurrences(of: "MWh", with: "megawattuur")
    }

    static func percent(_ value: Double) -> String {
        isTrace(value) ? "<1%" : "\(Int(value.rounded()))%"
    }

    static func percentSpoken(_ value: Double) -> String {
        isTrace(value) ? "minder dan 1 procent" : "\(Int(value.rounded())) procent"
    }

    private static func isTrace(_ value: Double) -> Bool {
        value > 0 && value < 0.5
    }

    static func number(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)).locale(locale))
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
