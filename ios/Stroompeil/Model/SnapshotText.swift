import Foundation

extension Snapshot {
    func isProvisional(now: Date) -> Bool {
        span == .day && date == DutchFormat.startOfDay(now)
    }

    func title(now: Date) -> String {
        switch span {
        case .hour: DutchFormat.long(date)
        case .day: DutchFormat.dayLong(date, now: now)
        }
    }

    func shortTitle(now: Date) -> String {
        switch span {
        case .hour: DutchFormat.compact(date)
        case .day: DutchFormat.dayCompact(date, now: now)
        }
    }

    func relativeTime(now: Date) -> String {
        switch span {
        case .hour: DutchFormat.relative(hour: date, now: now)
        case .day: DutchFormat.dayRelative(date, now: now)
        }
    }

    func usage(now: Date, spoken: Bool = false) -> String {
        let amount = spoken ? DutchFormat.gigawattHoursSpoken(totalKWh) : DutchFormat.gigawattHours(totalKWh)
        switch span {
        case .hour: return "\(amount) verbruik"
        case .day: return isProvisional(now: now) ? "\(amount) verbruik · voorlopig" : "\(amount) verbruik op deze dag"
        }
    }

    var missingDataMessage: String {
        switch span {
        case .hour: "Het Nationaal Energie Dashboard heeft voor dit uur nog geen cijfers."
        case .day: "Het Nationaal Energie Dashboard heeft voor deze dag nog geen cijfers."
        }
    }
}
