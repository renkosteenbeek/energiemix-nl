import Foundation
import Testing
@testable import Stroompeil

struct FormattingTests {
    private let november = ISODate.parse("2026-11-09T14:00:00Z")!
    private let july = ISODate.parse("2026-07-01T20:00:00Z")!
    private let nbsp = "\u{00A0}"

    @Test func longLabelUsesAmsterdamTimeIncludingDaylightSaving() {
        #expect(DutchFormat.long(november) == "maandag 9 november 15:00")
        #expect(DutchFormat.long(july) == "woensdag 1 juli 22:00")
    }

    @Test func compactLabelIsCapitalizedWithoutPeriods() {
        #expect(DutchFormat.compact(november) == "Ma 9 nov 15:00")
        #expect(DutchFormat.compact(july) == "Wo 1 jul 22:00")
    }

    @Test func weekdayAndHour() {
        #expect(DutchFormat.weekdayShort(november) == "ma")
        #expect(DutchFormat.amsterdamHour(november) == 15)
        #expect(DutchFormat.amsterdamHour(july) == 22)
        #expect(DutchFormat.clock(july) == "22:00")
    }

    @Test(arguments: [
        (15_808_146.0, "16"),
        (8_530_000.0, "8,5"),
        (9_960_000.0, "10"),
        (10_400_000.0, "10"),
        (0.0, "0,0"),
    ])
    func gigawattHours(kWh: Double, expected: String) {
        #expect(DutchFormat.gigawattHours(kWh) == "\(expected)\(nbsp)GWh")
    }

    @Test func megawattHoursUseDutchGrouping() {
        #expect(DutchFormat.megawattHours(14_699_000) == "14.699\(nbsp)MWh")
        #expect(DutchFormat.megawattHours(485_000) == "485\(nbsp)MWh")
        #expect(DutchFormat.megawattHoursSpoken(485_000) == "485\(nbsp)megawattuur")
    }

    @Test func percentRoundsHalfUp() {
        #expect(DutchFormat.percent(42.5) == "43%")
        #expect(DutchFormat.percent(42.49) == "42%")
        #expect(DutchFormat.percent(0.4) == "<1%")
        #expect(DutchFormat.percent(0) == "0%")
        #expect(DutchFormat.percentSpoken(0.2) == "minder dan 1 procent")
        #expect(DutchFormat.percentSpoken(61.5) == "62 procent")
    }

    @Test func relativeLabelComparesWholeHours() {
        let lateInHour = november.addingTimeInterval(59 * 60)
        #expect(DutchFormat.relative(hour: november, now: lateInHour) == "nu")
        #expect(DutchFormat.relative(hour: november.addingHours(1), now: lateInHour) == "over 1\(nbsp)uur")
        #expect(DutchFormat.relative(hour: november.addingHours(-1), now: november) == "1\(nbsp)uur geleden")
        #expect(DutchFormat.relative(hour: november.addingHours(24), now: november) == "over 24\(nbsp)uur")
        #expect(DutchFormat.relative(hour: november.addingHours(-40), now: november) == "2\(nbsp)dagen geleden")
        #expect(DutchFormat.relative(hour: november.addingHours(-720), now: november) == "4\(nbsp)weken geleden")
        #expect(DutchFormat.relative(hour: november.addingHours(-24 * 160), now: november) == "5\(nbsp)maanden geleden")
    }

    @Test func dayLabels() {
        let day = DutchFormat.day(fromISO: "2026-11-09")!
        let lastYear = DutchFormat.day(fromISO: "2025-11-10")!
        #expect(DutchFormat.dayLong(day, now: november) == "maandag 9 november")
        #expect(DutchFormat.dayLong(lastYear, now: november) == "maandag 10 november 2025")
        #expect(DutchFormat.dayCompact(day, now: november) == "Ma 9 nov")
        #expect(DutchFormat.dayCompact(lastYear, now: november) == "Ma 10 nov 2025")
        #expect(DutchFormat.dayShort(DutchFormat.day(fromISO: "2026-04-29")!, now: november) == "29 apr")
        #expect(DutchFormat.monthTitle(day) == "November 2026")
        #expect(DutchFormat.monthShort(DutchFormat.day(fromISO: "2026-03-15")!) == "MRT")
    }

    @Test func isoDaysRoundTripAcrossDaylightSaving() {
        for raw in ["2026-03-29", "2026-10-25", "2024-02-29", "2021-01-01"] {
            let day = DutchFormat.day(fromISO: raw)
            #expect(day != nil)
            #expect(day.map(DutchFormat.isoDay) == raw)
            #expect(day.map { DutchFormat.amsterdamHour($0) } == 0)
        }
        #expect(DutchFormat.day(fromISO: "gisteren") == nil)
    }

    @Test func relativeDayLabels() {
        let today = DutchFormat.day(fromISO: "2026-11-09")!
        func ago(_ days: Int) -> String {
            DutchFormat.dayRelative(DutchFormat.addingDays(-days, to: today), now: november)
        }
        #expect(ago(0) == "vandaag")
        #expect(ago(1) == "gisteren")
        #expect(ago(5) == "5\(nbsp)dagen geleden")
        #expect(ago(20) == "3\(nbsp)weken geleden")
        #expect(ago(100) == "3\(nbsp)maanden geleden")
        #expect(ago(800) == "2\(nbsp)jaar geleden")
    }

    @Test func hourMath() {
        let date = ISODate.parse("2026-11-09T14:59:59Z")!
        #expect(date.flooredToHour == november)
        #expect(november.hours(until: november.addingHours(-48)) == -48)
        #expect(november.flooredToHour == november)
    }

    @Test(arguments: [
        (29.4, GreenBand.low),
        (29.6, GreenBand.moderate),
        (49.4, GreenBand.moderate),
        (49.5, GreenBand.good),
        (69.4, GreenBand.good),
        (69.5, GreenBand.high),
        (100.0, GreenBand.high),
        (0.0, GreenBand.low),
    ])
    func greenBandMatchesDisplayedNumber(percentage: Double, band: GreenBand) {
        #expect(GreenBand(percentage: percentage) == band)
    }
}
