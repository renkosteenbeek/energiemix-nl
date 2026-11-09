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
        let days = Int((Double(magnitude) / 24).rounded())
        return delta < 0 ? "\(days)\u{00A0}dagen geleden" : "over \(days)\u{00A0}dagen"
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
        "\(Int(value.rounded()))%"
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
