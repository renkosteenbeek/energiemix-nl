import Foundation
import Testing
@testable import Stroompeil

struct PeriodWindowTests {
    private let today = DutchFormat.day(fromISO: "2026-11-09")!

    private func day(_ iso: String) -> Date {
        DutchFormat.day(fromISO: iso)!
    }

    @Test func monthWindowCoversCalendarMonth() {
        let window = PeriodWindow(scale: .month, anchor: day("2024-02-17"), today: today)
        #expect(window.count == 29)
        #expect(window.start == day("2024-02-01"))
        #expect(window.end == day("2024-02-29"))
        #expect(window.index(of: day("2024-02-17")) == 16)
        #expect(window.index(of: day("2024-03-01")) == nil)
        #expect(window.day(at: 28) == day("2024-02-29"))
        #expect(window.title == "Februari 2024")
    }

    @Test func yearWindowHandlesLeapYearsAndDaylightSaving() {
        #expect(PeriodWindow(scale: .year, anchor: day("2024-07-01"), today: today).count == 366)
        let window = PeriodWindow(scale: .year, anchor: day("2026-03-29"), today: today)
        #expect(window.count == 365)
        #expect(window.index(of: day("2026-03-29")) == 87)
        #expect(window.index(of: day("2026-03-30")) == 88)
        #expect(window.day(at: 88) == day("2026-03-30"))
        #expect(window.title == "2026")
    }

    @Test func navigationIsBoundedByDataAndToday() {
        #expect(PeriodWindow(scale: .month, anchor: day("2021-01-20"), today: today).canGoBack == false)
        #expect(PeriodWindow(scale: .month, anchor: day("2021-02-20"), today: today).canGoBack)
        #expect(PeriodWindow(scale: .month, anchor: today, today: today).canGoForward == false)
        #expect(PeriodWindow(scale: .month, anchor: day("2026-10-01"), today: today).canGoForward)
        #expect(PeriodWindow(scale: .year, anchor: day("2021-06-01"), today: today).canGoBack == false)
    }

    @Test func shiftingKeepsDayOfMonthWherePossible() {
        #expect(PeriodWindow(scale: .month, anchor: day("2024-03-31"), today: today).anchorShifted(by: -1) == day("2024-02-29"))
        #expect(PeriodWindow(scale: .month, anchor: day("2026-10-20"), today: today).anchorShifted(by: 1) == today)
        #expect(PeriodWindow(scale: .month, anchor: day("2021-02-10"), today: today).anchorShifted(by: -3) == PeriodWindow.earliestDay)
        #expect(PeriodWindow(scale: .year, anchor: day("2026-04-29"), today: today).anchorShifted(by: -1) == day("2025-04-29"))
    }

    @Test func statsWeighAverageByConsumption() throws {
        let days = [
            DayPoint(day: day("2026-01-01"), totalKWh: 100, greenPct: 80, volumes: []),
            DayPoint(day: day("2026-01-02"), totalKWh: 300, greenPct: 20, volumes: []),
            DayPoint(day: day("2026-01-03"), totalKWh: 0, greenPct: 0, volumes: []),
        ]
        let stats = try #require(PeriodStats(days: days))
        #expect(abs(stats.average - 35) < 0.0001)
        #expect(stats.greenest.day == day("2026-01-01"))
        #expect(stats.greyest.day == day("2026-01-02"))
        #expect(PeriodStats(days: []) == nil)
    }

    @Test func monthSummariesCoverYearWithWeightedAverages() {
        let window = PeriodWindow(scale: .year, anchor: day("2024-05-10"), today: today)
        let days: [Date: DayPoint] = [
            day("2024-01-01"): DayPoint(day: day("2024-01-01"), totalKWh: 300, greenPct: 20, volumes: []),
            day("2024-01-31"): DayPoint(day: day("2024-01-31"), totalKWh: 100, greenPct: 60, volumes: []),
            day("2024-02-29"): DayPoint(day: day("2024-02-29"), totalKWh: 100, greenPct: 50, volumes: []),
        ]
        let summaries = window.monthSummaries(days: days)
        #expect(summaries.count == 12)
        #expect(summaries[0].startIndex == 0)
        #expect(summaries[0].endIndex == 30)
        #expect(summaries[0].average == 30)
        #expect(summaries[1].startIndex == 31)
        #expect(summaries[1].endIndex == 59)
        #expect(summaries[1].average == 50)
        #expect(summaries[2].average == nil)
        #expect(summaries[11].endIndex == 365)
        #expect(summaries[1].contains(45))
        #expect(summaries[1].contains(60) == false)
    }
}
