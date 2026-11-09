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
        await eventually { model.displayedMix != nil && model.storyPhase == .ready }

        #expect(model.displayedMix?.hour == start.flooredToHour)
        #expect(model.story == "Het waait flink.")
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
        await eventually { model.mixError != nil && model.storyPhase == .unavailable }

        #expect(model.displayedMix == nil)
        #expect(model.mixError == "Geen internetverbinding.")
        #expect(model.storyPhase == .unavailable)

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
        await eventually { model.displayedMix?.hour == earlier && model.storyPhase == .ready }

        clock.advance(hours: 1)
        model.clockTick()
        #expect(model.storyPhase == .ready)
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
        #expect(model.displayedMix?.hasData == false)
    }

    @Test func failedTimelineCanBeRetried() async {
        let source = StubSource()
        source.timelineFailure = .server(status: 502)
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        await eventually { model.timelineFailed }
        #expect(model.timeline.isEmpty)

        source.timelineFailure = nil
        model.retryTimeline()
        await eventually { !model.timelineFailed }
        #expect(model.timeline.count == 1)
    }

    @Test func failedStoryCanBeRetried() async {
        let source = StubSource()
        source.storyFailure = .timeout
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        await eventually { model.storyPhase == .unavailable }
        #expect(model.story.isEmpty)

        source.storyFailure = nil
        model.retryStory()
        await eventually { model.storyPhase == .ready }
        #expect(model.story == "Het waait flink.")
    }

    @Test func returningToForegroundRecoversFromErrors() async {
        let source = StubSource()
        source.failure = .offline
        let model = makeModel(source: source, clock: TestClock(start))
        model.start()
        await eventually { model.mixError != nil && model.timelineFailed }

        source.failure = nil
        model.sceneBecameActive()
        await eventually { model.displayedMix != nil && !model.timelineFailed && model.storyPhase == .ready }
        #expect(model.mixError == nil)
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

    @Test func widgetsReloadOncePerHour() async {
        var reloads = 0
        let model = makeModel(source: StubSource(), clock: TestClock(start)) { reloads += 1 }
        model.start()
        await eventually { model.displayedMix != nil }
        await model.refresh()
        #expect(reloads == 1)
    }
}
