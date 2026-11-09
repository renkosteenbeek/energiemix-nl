import Foundation
import Testing
@testable import Stroompeil

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ date: Date) {
        current = date
    }

    var now: Date {
        lock.withLock { current }
    }

    func advance(hours: Int) {
        lock.withLock { current = current.addingHours(hours) }
    }
}

final class StubSource: EnergyDataSource, @unchecked Sendable {
    private let lock = NSLock()
    private var _failure: APIError?
    private var _timelineFailure: APIError?
    private var _storyFailure: APIError?
    private var _mixHourShift = 0
    private var _requestedHours: [Date] = []
    private var _rangeRequests: [ClosedRange<Date>] = []
    private var _requestedYears: [Int] = []
    private var _delays: [Date: Duration] = [:]
    let storyText: String

    init(storyText: String = "Het waait flink.") {
        self.storyText = storyText
    }

    var failure: APIError? {
        get { lock.withLock { _failure } }
        set { lock.withLock { _failure = newValue } }
    }

    var timelineFailure: APIError? {
        get { lock.withLock { _timelineFailure } }
        set { lock.withLock { _timelineFailure = newValue } }
    }

    var storyFailure: APIError? {
        get { lock.withLock { _storyFailure } }
        set { lock.withLock { _storyFailure = newValue } }
    }

    var mixHourShift: Int {
        get { lock.withLock { _mixHourShift } }
        set { lock.withLock { _mixHourShift = newValue } }
    }

    var requestedHours: [Date] { lock.withLock { _requestedHours } }
    var rangeRequests: [ClosedRange<Date>] { lock.withLock { _rangeRequests } }
    var requestedYears: [Int] { lock.withLock { _requestedYears } }

    func setDelay(_ delay: Duration, for hour: Date) {
        lock.withLock { _delays[hour] = delay }
    }

    func mix(at hour: Date, reload: Bool) async throws -> Mix {
        let (failure, delay, shift) = lock.withLock { () -> (APIError?, Duration?, Int) in
            _requestedHours.append(hour)
            return (_failure, _delays[hour], _mixHourShift)
        }
        if let delay { try await Task.sleep(for: delay) }
        if let failure { throw failure }
        return Mix(
            focusTime: hour.addingHours(shift),
            greenPct: 40,
            totalKWh: 15_000_000,
            sources: [SourceSlice(typeId: 18, label: "Aardgas", category: .grijs, volumeKWh: 9_000_000, percentage: 60)]
        )
    }

    func timeline(reload: Bool) async throws -> [TimePoint] {
        if let failure = timelineFailure ?? failure { throw failure }
        return [TimePoint(time: Date().flooredToHour, greenPct: 40, totalKWh: 15_000_000)]
    }

    func timeline(from: Date, to: Date) async throws -> [TimePoint] {
        lock.withLock { _rangeRequests.append(from...to) }
        return stride(from: 0, through: from.hours(until: to), by: 1).map {
            TimePoint(time: from.addingHours($0), greenPct: 55, totalKWh: 14_000_000)
        }
    }

    func year(_ year: Int, reload: Bool) async throws -> YearData {
        lock.withLock { _requestedYears.append(year) }
        if let failure { throw failure }
        let calendar = DutchFormat.calendar
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let count = calendar.range(of: .day, in: .year, for: start)!.count
        let days = (0..<count).map { offset -> DayPoint in
            let green = Double(20 + offset % 60)
            return DayPoint(
                day: DutchFormat.addingDays(offset, to: start),
                totalKWh: 300_000_000,
                greenPct: green,
                volumes: [green * 3_000_000, (100 - green) * 3_000_000]
            )
        }
        return YearData(
            year: year,
            sources: [
                SourceMeta(typeId: 2, label: "Zon", category: .groen),
                SourceMeta(typeId: 18, label: "Aardgas", category: .grijs),
            ],
            days: days
        )
    }

    func dayStory(_ day: Date, reload: Bool) -> AsyncThrowingStream<String, Error> {
        let label = DutchFormat.isoDay(day)
        return AsyncThrowingStream { continuation in
            continuation.yield("Dag \(label).")
            continuation.finish()
        }
    }

    func story(at hour: Date, reload: Bool) -> AsyncThrowingStream<String, Error> {
        let text = storyText
        let failure = storyFailure ?? failure
        return AsyncThrowingStream { continuation in
            if let failure {
                continuation.finish(throwing: failure)
            } else {
                continuation.yield("Het ")
                continuation.yield(text)
                continuation.finish()
            }
        }
    }
}

@MainActor
struct DashboardModelTests {
    private let start = ISODate.parse("2026-11-09T14:20:00Z")!

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<300 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func makeModel(source: StubSource, clock: TestClock, widgetReloads: (() -> Void)? = nil) -> DashboardModel {
        DashboardModel(source: source, clock: { clock.now }, reloadWidgets: { widgetReloads?() })
    }

    @Test func startLoadsCurrentHourAndStory() async {
        let source = StubSource()
        let clock = TestClock(start)
        let model = makeModel(source: source, clock: clock)
        model.start()
        await eventually { model.displayedMix != nil && model.story.phase == .ready }

        #expect(model.displayedMix?.hour == start.flooredToHour)
        #expect(model.story.text == "Het waait flink.")
        #expect(model.isAtNow)
        #expect(model.mixError == nil)
    }

    @Test func selectingAndReturningReusesCache() async {
        let source = StubSource()
        let clock = TestClock(start)
        let model = makeModel(source: source, clock: clock)
        model.start()
        await eventually { model.displayedMix != nil }

        let earlier = model.nowHour.addingHours(-5)
        model.select(earlier)
        #expect(model.isAtNow == false)
        await eventually { model.displayedMix?.hour == earlier }

        model.jumpToNow()
        #expect(model.isAtNow)
        #expect(model.displayedMix?.hour == model.nowHour)
        #expect(source.requestedHours.filter { $0 == model.nowHour }.count == 1)
    }

    @Test func selectionIsClampedToWindow() async {
        let model = makeModel(source: StubSource(), clock: TestClock(start))
        model.start()
        model.select(model.nowHour.addingHours(200))
        #expect(model.focusHour == model.window.endHour)
    }

    @Test func failureShowsMessageAndRetryRecovers() async {
        let source = StubSource()
        source.failure = .offline
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        await eventually { model.mixError != nil && model.story.phase == .unavailable }

        #expect(model.displayedMix == nil)
        #expect(model.mixError == "Geen internetverbinding.")
        #expect(model.story.phase == .unavailable)

        source.failure = nil
        model.retry()
        await eventually { model.displayedMix != nil }
        #expect(model.mixError == nil)
    }

    @Test func hourRolloverFollowsNowWhenUserWasAtNow() async {
        let source = StubSource()
        let clock = TestClock(start)
        let model = makeModel(source: source, clock: clock)
        model.start()
        await eventually { model.displayedMix != nil }

        clock.advance(hours: 1)
        model.clockTick()
        #expect(model.nowHour == start.flooredToHour.addingHours(1))
        #expect(model.focusHour == model.nowHour)
        await eventually { model.displayedMix?.hour == model.nowHour }
    }

    @Test func hourRolloverKeepsHistoricalSelection() async {
        let clock = TestClock(start)
        let model = makeModel(source: StubSource(), clock: clock)
        model.start()
        let earlier = model.nowHour.addingHours(-10)
        model.select(earlier)

        clock.advance(hours: 1)
        model.clockTick()
        #expect(model.focusHour == earlier)
        #expect(model.isAtNow == false)
    }

    @Test func hourRolloverKeepsSettledContentWithoutReloading() async {
        let source = StubSource()
        let clock = TestClock(start)
        let model = makeModel(source: source, clock: clock)
        model.start()
        let earlier = model.nowHour.addingHours(-10)
        model.select(earlier)
        await eventually { model.displayedMix?.hour == earlier && model.story.phase == .ready }

        clock.advance(hours: 1)
        model.clockTick()
        #expect(model.story.phase == .ready)
        #expect(model.isLoadingMix == false)
        #expect(source.requestedHours.filter { $0 == earlier }.count == 1)
    }

    @Test func mixForAnotherHourIsTreatedAsMissingData() async {
        let source = StubSource()
        source.mixHourShift = -2
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        await eventually { model.displayedMix != nil }
        #expect(model.displayedMix?.hour == model.nowHour)
        #expect(model.snapshot?.hasData == false)
    }

    @Test func failedTimelineCanBeRetried() async {
        let source = StubSource()
        source.timelineFailure = .server(status: 502)
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        await eventually { model.hourly.failed }
        #expect(model.hourly.points.isEmpty)

        source.timelineFailure = nil
        model.hourly.loadRecent(reload: true)
        await eventually { !model.hourly.failed }
        #expect(model.hourly.points.count == 1)
    }

    @Test func failedStoryCanBeRetried() async {
        let source = StubSource()
        source.storyFailure = .timeout
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        await eventually { model.story.phase == .unavailable }
        #expect(model.story.text.isEmpty)

        source.storyFailure = nil
        model.story.retry()
        await eventually { model.story.phase == .ready }
        #expect(model.story.text == "Het waait flink.")
    }

    @Test func returningToForegroundRecoversFromErrors() async {
        let source = StubSource()
        source.failure = .offline
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        await eventually { model.mixError != nil && model.hourly.failed }

        source.failure = nil
        model.sceneBecameActive()
        await eventually { model.displayedMix != nil && !model.hourly.failed && model.story.phase == .ready }
        #expect(model.mixError == nil)
    }

    @Test func zoomingOutSelectsTheDayOfTheFocusedHour() async {
        let source = StubSource()
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        let earlier = model.nowHour.addingHours(-30)
        model.select(earlier)

        model.zoom(to: .month)
        #expect(model.scale == .month)
        #expect(model.focusDay == DutchFormat.startOfDay(earlier))
        await eventually { model.snapshot?.span == .day && model.story.phase == .ready }
        #expect(model.snapshot?.date == model.focusDay)
        #expect(model.story.text == "Dag \(DutchFormat.isoDay(model.focusDay)).")
        #expect(model.periodStats != nil)
    }

    @Test func selectingDaysUsesLoadedYearWithoutExtraRequests() async {
        let source = StubSource()
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        model.zoom(to: .year)
        await eventually { model.snapshot != nil }
        let mixRequests = source.requestedHours.count
        let yearRequests = source.requestedYears.count

        let day = DutchFormat.day(fromISO: "2026-04-29")!
        model.selectDay(day)
        #expect(model.snapshot?.date == day)
        #expect(model.snapshot?.sources.first?.label == "Aardgas" || model.snapshot?.sources.first?.label == "Zon")
        #expect(source.requestedHours.count == mixRequests)
        #expect(source.requestedYears.count == yearRequests)
    }

    @Test func zoomingInLandsOnSameHourOfTheChosenDay() async {
        let source = StubSource()
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        let localHour = DutchFormat.amsterdamHour(model.nowHour)
        model.zoom(to: .year)
        let day = DutchFormat.day(fromISO: "2026-06-03")!
        model.selectDay(day)

        model.zoom(to: .day)
        #expect(model.scale == .day)
        #expect(DutchFormat.startOfDay(model.focusHour) == day)
        #expect(DutchFormat.amsterdamHour(model.focusHour) == localHour)
        #expect(model.windowOffset < 0)
        #expect(model.window.index(of: model.focusHour) != nil)
        await eventually { !source.rangeRequests.isEmpty && model.displayedMix?.hour == model.focusHour }
        #expect(source.rangeRequests.first?.contains(model.focusHour) == true)
        #expect(model.hourly.points[model.focusHour] != nil)
    }

    @Test func periodNavigationStepsByMonthAndYear() async {
        let model = makeModel(source: StubSource(), clock: TestClock(start))
        model.start()
        model.zoom(to: .month)
        #expect(model.canPanForward == false)
        #expect(model.isAtNow)

        model.panBack()
        #expect(model.periodWindow.title == "Oktober 2026")
        #expect(model.focusDay == DutchFormat.day(fromISO: "2026-10-09"))
        #expect(model.canPanForward)
        #expect(model.isAtNow == false)

        model.zoom(to: .year)
        model.panBack()
        #expect(model.periodWindow.title == "2025")
        model.jumpToNow()
        #expect(model.focusDay == model.today)
        #expect(model.periodWindow.title == "2026")
    }

    @Test func daySelectionIsClampedToAvailableRange() async {
        let model = makeModel(source: StubSource(), clock: TestClock(start))
        model.start()
        model.zoom(to: .year)
        model.selectDay(DutchFormat.day(fromISO: "2019-05-01")!)
        #expect(model.focusDay == PeriodWindow.earliestDay)
        model.selectDay(DutchFormat.day(fromISO: "2027-01-01")!)
        #expect(model.focusDay == model.today)
    }

    @Test func panningMovesWindowAndFocusTogether() async {
        let model = makeModel(source: StubSource(), clock: TestClock(start))
        model.start()
        let now = model.nowHour
        #expect(model.canPanForward == false)
        #expect(model.canPanBack)

        model.panBack()
        #expect(model.windowOffset == -24)
        #expect(model.focusHour == now.addingHours(-24))
        #expect(model.isAtNow == false)

        model.select(now.addingHours(-2))
        model.panForward()
        #expect(model.windowOffset == 0)
        #expect(model.focusHour == now.addingHours(22))
    }

    @Test func slowOlderResponseDoesNotOverwriteNewerSelection() async {
        let source = StubSource()
        let model = makeModel(source: source, clock: TestClock(start))
        let slowHour = start.flooredToHour.addingHours(-3)
        let fastHour = start.flooredToHour.addingHours(-4)
        source.setDelay(.milliseconds(300), for: slowHour)

        model.start()
        model.select(slowHour)
        model.select(fastHour)
        await eventually { model.displayedMix?.hour == fastHour }
        try? await Task.sleep(for: .milliseconds(400))
        #expect(model.displayedMix?.hour == fastHour)
    }

    @Test func deepLinkFromPeriodViewReturnsToCurrentHour() async {
        let model = makeModel(source: StubSource(), clock: TestClock(start))
        model.start()
        model.zoom(to: .year)
        model.selectDay(DutchFormat.day(fromISO: "2026-03-14")!)

        model.showNow()
        #expect(model.scale == .day)
        #expect(model.focusHour == model.nowHour)
        #expect(model.windowOffset == 0)
        #expect(model.isAtNow)
    }

    @Test func periodStatsLeaveOutTheProvisionalToday() async {
        let model = makeModel(source: StubSource(), clock: TestClock(start))
        model.start()
        model.zoom(to: .month)
        await eventually { !model.periodDays.isEmpty }

        #expect(model.periodDays.contains { $0.day == model.today })
        let stats = model.periodStats
        #expect(stats != nil)
        #expect(stats?.greenest.day != model.today)
        #expect(stats?.greyest.day != model.today)
    }

    @Test func zoomingInNearTheFirstDayStaysWithinAvailableData() async {
        let model = makeModel(source: StubSource(), clock: TestClock(start))
        model.start()
        model.zoom(to: .year)
        model.selectDay(PeriodWindow.earliestDay)

        model.zoom(to: .day)
        #expect(model.focusHour >= PeriodWindow.earliestDay)
        #expect(model.window.index(of: model.focusHour) != nil)
        #expect(model.windowOffset == model.window.earliestOffset(earliest: PeriodWindow.earliestDay))
        #expect(model.canPanBack == false)

        model.select(PeriodWindow.earliestDay.addingHours(-6))
        #expect(model.focusHour == PeriodWindow.earliestDay)
    }

    @Test func revisitingALoadedRangeDoesNotFetchItAgain() async {
        let source = StubSource()
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        model.zoom(to: .year)
        model.selectDay(DutchFormat.day(fromISO: "2026-06-03")!)
        model.zoom(to: .day)
        await eventually { !source.rangeRequests.isEmpty }
        try? await Task.sleep(for: .milliseconds(50))

        model.zoom(to: .month)
        model.zoom(to: .day)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(source.rangeRequests.count == 1)
    }

    @Test func widgetsReloadOncePerHour() async {
        var reloads = 0
        let model = makeModel(source: StubSource(), clock: TestClock(start)) { reloads += 1 }
        model.start()
        await eventually { model.displayedMix != nil }
        await model.refresh()
        #expect(reloads == 1)
    }
}
