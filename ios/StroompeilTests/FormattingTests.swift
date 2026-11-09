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
        #expect(DutchFormat.percent(0.4) == "0%")
    }

    @Test func relativeLabelComparesWholeHours() {
        let lateInHour = november.addingTimeInterval(59 * 60)
        #expect(DutchFormat.relative(hour: november, now: lateInHour) == "nu")
        #expect(DutchFormat.relative(hour: november.addingHours(1), now: lateInHour) == "over 1\(nbsp)uur")
        #expect(DutchFormat.relative(hour: november.addingHours(-1), now: november) == "1\(nbsp)uur geleden")
        #expect(DutchFormat.relative(hour: november.addingHours(24), now: november) == "over 24\(nbsp)uur")
        #expect(DutchFormat.relative(hour: november.addingHours(-40), now: november) == "2\(nbsp)dagen geleden")
        #expect(DutchFormat.relative(hour: november.addingHours(-720), now: november) == "30\(nbsp)dagen geleden")
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
