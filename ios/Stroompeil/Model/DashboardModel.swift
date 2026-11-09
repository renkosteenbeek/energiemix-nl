import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class DashboardModel {
    let hourly: HourlySeries
    let history: DailyHistory
    let story: StoryFeed

    private(set) var nowHour: Date
    private(set) var scale: TimeScale = .day
    private(set) var focusHour: Date
    private(set) var windowOffset = 0
    private(set) var focusDay: Date
    private(set) var displayedMix: Mix?
    private(set) var isLoadingMix = false
    private(set) var mixError: String?

    @ObservationIgnored private let source: any EnergyDataSource
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private let reloadWidgets: @MainActor () -> Void
    @ObservationIgnored private var mixCache: [Date: Mix] = [:]
    @ObservationIgnored private var mixTask: Task<Void, Never>?
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var lastWidgetReloadHour: Date?

    init(
        source: any EnergyDataSource = APIClient.live,
        clock: @escaping @Sendable () -> Date = { Date() },
        reloadWidgets: @escaping @MainActor () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind) }
    ) {
        self.source = source
        self.clock = clock
        self.reloadWidgets = reloadWidgets
        hourly = HourlySeries(source: source)
        history = DailyHistory(source: source, clock: clock)
        story = StoryFeed(source: source)
        let hour = clock().flooredToHour
        nowHour = hour
        focusHour = hour
        focusDay = DutchFormat.startOfDay(hour)
    }

    var today: Date { DutchFormat.startOfDay(nowHour) }
    var window: RhythmWindow { RhythmWindow(nowHour: nowHour, offset: windowOffset) }
    var periodWindow: PeriodWindow { PeriodWindow(scale: scale, anchor: focusDay, today: today) }

    var isAtNow: Bool {
        scale == .day ? focusHour == nowHour && windowOffset == 0 : focusDay == today
    }

    var canPanBack: Bool {
        scale == .day ? window.canPanBack(earliest: PeriodWindow.earliestDay) : periodWindow.canGoBack
    }

    var canPanForward: Bool {
        scale == .day ? window.canPanForward : periodWindow.canGoForward
    }

    var snapshot: Snapshot? {
        scale == .day ? displayedMix.map(Snapshot.init(mix:)) : history.snapshot(for: focusDay)
    }

    var isLoadingSnapshot: Bool {
        scale == .day ? isLoadingMix : history.loadingYears.contains(DutchFormat.year(focusDay))
    }

    var snapshotError: String? {
        if scale == .day { return mixError }
        let year = DutchFormat.year(focusDay)
        guard history.failedYears.contains(year), history.days[focusDay] == nil else { return nil }
        return "De gegevens van \(year) konden niet worden geladen."
    }

    var periodDays: [DayPoint] {
        let window = periodWindow
        return (0..<window.count).compactMap { history.days[window.day(at: $0)] }
    }

    var periodStats: PeriodStats? {
        PeriodStats(days: periodDays.filter { $0.day != today })
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        hourly.loadRecent(reload: false)
        loadFocus(reload: false)
        history.ensure(DutchFormat.year(nowHour))
    }

    func select(_ hour: Date) {
        let target = max(window.clamp(hour), PeriodWindow.earliestDay)
        guard target != focusHour else { return }
        focusHour = target
        loadFocus(reload: false)
    }

    func selectDay(_ day: Date) {
        let target = PeriodWindow.clamp(day, today: today)
        guard target != focusDay else { return }
        focusDay = target
        loadFocus(reload: false)
    }

    func step(by amount: Int) {
        if scale == .day {
            select(focusHour.addingHours(amount))
        } else {
            selectDay(DutchFormat.addingDays(amount, to: focusDay))
        }
    }

    func showNow() {
        zoom(to: .day)
        jumpToNow()
    }

    func jumpToNow() {
        clockTick()
        guard scale == .day else {
            selectDay(today)
            return
        }
        windowOffset = 0
        guard focusHour != nowHour else { return }
        focusHour = nowHour
        loadFocus(reload: false)
    }

    func panBack() {
        guard canPanBack else { return }
        if scale == .day {
            apply(offset: window.offsetAfterPanBack(earliest: PeriodWindow.earliestDay))
        } else {
            selectDay(periodWindow.anchorShifted(by: -1))
        }
    }

    func panForward() {
        guard canPanForward else { return }
        if scale == .day {
            apply(offset: window.offsetAfterPanForward)
        } else {
            selectDay(periodWindow.anchorShifted(by: 1))
        }
    }

    func zoom(to newScale: TimeScale) {
        guard newScale != scale else { return }
        if scale == .day {
            focusDay = PeriodWindow.clamp(focusHour, today: today)
        }
        scale = newScale
        if newScale == .day {
            alignHourWithFocusDay()
        }
        loadFocus(reload: false)
    }

    func retry() {
        if scale == .day, hourly.failed { hourly.loadRecent(reload: true) }
        loadFocus(reload: true)
    }

    func sceneBecameActive() {
        clockTick()
        guard hasStarted else { return }
        if hourly.failed { hourly.loadRecent(reload: true) }
        if snapshotError != nil {
            loadFocus(reload: true)
        } else if story.phase == .unavailable {
            story.retry()
        }
    }

    func refresh() async {
        clockTick()
        mixCache.removeAll()
        story.forgetAll()
        let recent = hourly.loadRecent(reload: true)
        let currentYear = history.ensure(DutchFormat.year(nowHour), reload: true)
        loadFocus(reload: true)
        await recent.value
        await currentYear?.value
        await mixTask?.value
    }

    func clockTick() {
        let current = clock().flooredToHour
        guard current != nowHour else { return }
        let previous = nowHour
        let previousDay = DutchFormat.startOfDay(previous)
        let followNow = focusHour == previous && windowOffset == 0
        let followToday = focusDay == previousDay
        nowHour = current

        let settledBefore = previous.addingHours(-2)
        mixCache = mixCache.filter { $0.key < settledBefore }
        story.forget { key in
            switch key {
            case .hour(let hour): hour >= settledBefore
            case .day(let day): day >= previousDay
            }
        }

        let target = followNow ? current : window.clamp(focusHour)
        let hourChanged = target != focusHour || mixCache[target] == nil
        focusHour = target
        if followToday { focusDay = today }

        guard hasStarted else { return }
        hourly.loadRecent(reload: true)
        history.ensure(DutchFormat.year(current))
        if scale != .day || hourChanged {
            loadFocus(reload: false)
        }
    }

    private func alignHourWithFocusDay() {
        if DutchFormat.startOfDay(focusHour) != focusDay {
            let hourOfDay = DutchFormat.amsterdamHour(focusHour)
            let candidate = DutchFormat.calendar.date(bySettingHour: hourOfDay, minute: 0, second: 0, of: focusDay) ?? focusDay
            let target = max(min(candidate.flooredToHour, nowHour), PeriodWindow.earliestDay)
            let earliestOffset = window.earliestOffset(earliest: PeriodWindow.earliestDay)
            windowOffset = max(earliestOffset, min(0, nowHour.hours(until: target) + 12))
            focusHour = target
        }
        hourly.ensureCoverage(of: window, until: nowHour.addingHours(RhythmWindow.hoursForward))
    }

    private func apply(offset newOffset: Int) {
        let delta = newOffset - windowOffset
        guard delta != 0 else { return }
        windowOffset = newOffset
        hourly.ensureCoverage(of: window, until: nowHour.addingHours(RhythmWindow.hoursForward))
        let target = max(window.clamp(focusHour.addingHours(delta)), PeriodWindow.earliestDay)
        guard target != focusHour else { return }
        focusHour = target
        loadFocus(reload: false)
    }

    private func loadFocus(reload: Bool) {
        switch scale {
        case .day:
            loadMix(reload: reload)
            story.show(.hour(focusHour), reload: reload)
        case .month, .year:
            history.ensure(DutchFormat.year(focusDay), reload: reload)
            story.show(.day(focusDay), reload: reload)
        }
    }

    private func loadMix(reload: Bool) {
        mixTask?.cancel()
        let hour = focusHour
        mixError = nil
        if !reload, let cached = mixCache[hour] {
            displayedMix = cached
            isLoadingMix = false
            mixTask = nil
            return
        }
        isLoadingMix = true
        mixTask = Task { await fetchMix(hour: hour, reload: reload) }
    }

    private func fetchMix(hour: Date, reload: Bool) async {
        do {
            let received = try await source.mix(at: hour, reload: reload)
            guard !Task.isCancelled, hour == focusHour else { return }
            let mix = received.hour == hour ? received : Mix(focusTime: hour, greenPct: 0, totalKWh: 0, sources: [])
            mixCache[hour] = mix
            displayedMix = mix
            isLoadingMix = false
            if hour == nowHour, Snapshot(mix: mix).hasData, lastWidgetReloadHour != hour {
                lastWidgetReloadHour = hour
                reloadWidgets()
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, hour == focusHour else { return }
            isLoadingMix = false
            mixError = (error as? LocalizedError)?.errorDescription ?? APIError.invalidResponse.errorDescription
        }
    }
}
