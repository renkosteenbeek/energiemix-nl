import Foundation
import Observation
import WidgetKit

enum StoryPhase: Equatable, Sendable {
    case idle
    case loading
    case streaming
    case ready
    case unavailable
}

private enum StoryKey: Hashable {
    case hour(Date)
    case day(Date)
}

@MainActor
@Observable
final class DashboardModel {
    private(set) var nowHour: Date
    private(set) var scale: TimeScale = .day

    private(set) var focusHour: Date
    private(set) var windowOffset = 0
    private(set) var timelineByHour: [Date: TimePoint] = [:]
    private(set) var timelineFailed = false
    private(set) var displayedMix: Mix?
    private(set) var isLoadingMix = false
    private(set) var mixError: String?

    private(set) var focusDay: Date
    private(set) var sourceMeta: [SourceMeta] = []
    private(set) var daysByDate: [Date: DayPoint] = [:]
    private(set) var loadingYears: Set<Int> = []
    private(set) var failedYears: Set<Int> = []

    private(set) var story = ""
    private(set) var storyPhase: StoryPhase = .idle

    @ObservationIgnored private let source: any EnergyDataSource
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private let reloadWidgets: @MainActor () -> Void
    @ObservationIgnored private var mixCache: [Date: Mix] = [:]
    @ObservationIgnored private var storyCache: [StoryKey: String] = [:]
    @ObservationIgnored private var mixTask: Task<Void, Never>?
    @ObservationIgnored private var storyTask: Task<Void, Never>?
    @ObservationIgnored private var timelineTask: Task<Void, Never>?
    @ObservationIgnored private var rangeTask: Task<Void, Never>?
    @ObservationIgnored private var yearTasks: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var yearLoadedAt: [Int: Date] = [:]
    @ObservationIgnored private var loadedHourRanges: [ClosedRange<Date>] = []
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
        let hour = clock().flooredToHour
        nowHour = hour
        focusHour = hour
        focusDay = DutchFormat.startOfDay(hour)
    }

    var today: Date { DutchFormat.startOfDay(nowHour) }
    var window: RhythmWindow { RhythmWindow(nowHour: nowHour, offset: windowOffset) }
    var periodWindow: PeriodWindow { PeriodWindow(scale: scale, anchor: focusDay, today: today) }
    var earliestHour: Date { PeriodWindow.earliestDay }

    var isAtNow: Bool {
        scale == .day ? focusHour == nowHour && windowOffset == 0 : focusDay == today
    }

    var canPanBack: Bool {
        scale == .day ? window.canPanBack(earliest: earliestHour) : periodWindow.canGoBack
    }

    var canPanForward: Bool {
        scale == .day ? window.canPanForward : periodWindow.canGoForward
    }

    var snapshot: Snapshot? {
        switch scale {
        case .day:
            return displayedMix.map(Snapshot.init(mix:))
        case .month, .year:
            if let point = daysByDate[focusDay] {
                return Snapshot(day: point, sources: sourceMeta)
            }
            guard yearLoadedAt[DutchFormat.year(focusDay)] != nil else { return nil }
            return Snapshot(day: DayPoint(day: focusDay, totalKWh: 0, greenPct: 0, volumes: []), sources: sourceMeta)
        }
    }

    var isLoadingSnapshot: Bool {
        scale == .day ? isLoadingMix : loadingYears.contains(DutchFormat.year(focusDay))
    }

    var snapshotError: String? {
        switch scale {
        case .day:
            return mixError
        case .month, .year:
            guard failedYears.contains(DutchFormat.year(focusDay)), daysByDate[focusDay] == nil else { return nil }
            return "De gegevens van \(DutchFormat.year(focusDay)) konden niet worden geladen."
        }
    }

    var periodDays: [DayPoint] {
        let window = periodWindow
        return (0..<window.count).compactMap { daysByDate[window.day(at: $0)] }
    }

    var periodStats: PeriodStats? { PeriodStats(days: periodDays) }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        loadTimeline(reload: false)
        loadFocus(reload: false)
        ensureYear(DutchFormat.year(nowHour))
    }

    func select(_ hour: Date) {
        let target = window.clamp(hour)
        guard target != focusHour else { return }
        focusHour = target
        loadFocus(reload: false)
    }

    func selectDay(_ day: Date) {
        let target = PeriodWindow.clamp(day, today: today)
        guard target != focusDay else { return }
        focusDay = target
        loadDayFocus(reload: false)
    }

    func step(by amount: Int) {
        if scale == .day {
            select(focusHour.addingHours(amount))
        } else {
            selectDay(DutchFormat.addingDays(amount, to: focusDay))
        }
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
            apply(offset: window.offsetAfterPanBack(earliest: earliestHour))
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
            enterHourScale()
        } else {
            loadDayFocus(reload: false)
        }
    }

    func zoomOut() {
        if let coarser = scale.coarser { zoom(to: coarser) }
    }

    func zoomIn(at day: Date? = nil) {
        if let day, scale != .day { selectDay(day) }
        if let finer = scale.finer { zoom(to: finer) }
    }

    func retry() {
        if scale == .day {
            if timelineByHour.isEmpty { loadTimeline(reload: true) }
            loadFocus(reload: true)
        } else {
            ensureYear(DutchFormat.year(focusDay), reload: true)
            loadStory(reload: true)
        }
    }

    func retryTimeline() {
        loadTimeline(reload: true)
    }

    func retryStory() {
        loadStory(reload: true)
    }

    func sceneBecameActive() {
        clockTick()
        guard hasStarted else { return }
        if timelineFailed {
            loadTimeline(reload: true)
        }
        if scale != .day, failedYears.contains(DutchFormat.year(focusDay)) {
            ensureYear(DutchFormat.year(focusDay), reload: true)
        }
        if scale == .day, mixError != nil {
            loadFocus(reload: true)
        } else if storyPhase == .unavailable {
            retryStory()
        }
    }

    func refresh() async {
        clockTick()
        mixCache.removeAll()
        storyCache.removeAll()
        loadTimeline(reload: true)
        let currentYear = DutchFormat.year(nowHour)
        ensureYear(currentYear, reload: true)
        if scale == .day {
            loadFocus(reload: true)
        } else {
            let focusYear = DutchFormat.year(focusDay)
            if focusYear != currentYear { ensureYear(focusYear, reload: true) }
            loadStory(reload: true)
        }
        await timelineTask?.value
        await mixTask?.value
        await yearTasks[DutchFormat.year(focusDay)]?.value
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
        storyCache = storyCache.filter { entry in
            switch entry.key {
            case .hour(let hour): hour < settledBefore
            case .day(let day): day < previousDay
            }
        }

        let target = followNow ? current : window.clamp(focusHour)
        let needsLoad = target != focusHour || mixCache[target] == nil
        focusHour = target
        if followToday { focusDay = today }

        guard hasStarted else { return }
        loadTimeline(reload: true)
        ensureYear(DutchFormat.year(current), reload: true)
        if scale == .day {
            if needsLoad { loadFocus(reload: false) }
        } else {
            loadDayFocus(reload: false)
        }
    }

    private func enterHourScale() {
        if DutchFormat.startOfDay(focusHour) != focusDay {
            let hourOfDay = DutchFormat.amsterdamHour(focusHour)
            let candidate = DutchFormat.calendar.date(bySettingHour: hourOfDay, minute: 0, second: 0, of: focusDay) ?? focusDay
            let target = min(candidate.flooredToHour, nowHour)
            windowOffset = min(0, nowHour.hours(until: target) + 12)
            focusHour = target
        }
        loadFocus(reload: false)
        ensureHourlyCoverage()
    }

    private func apply(offset newOffset: Int) {
        let delta = newOffset - windowOffset
        guard delta != 0 else { return }
        windowOffset = newOffset
        ensureHourlyCoverage()
        let target = window.clamp(focusHour.addingHours(delta))
        guard target != focusHour else { return }
        focusHour = target
        loadFocus(reload: false)
    }

    private func merge(_ points: [TimePoint]) {
        guard !points.isEmpty else { return }
        var index = timelineByHour
        for point in points {
            index[point.time.flooredToHour] = point
        }
        timelineByHour = index
    }

    private func loadTimeline(reload: Bool) {
        timelineTask?.cancel()
        timelineTask = Task { [source] in
            do {
                let points = try await source.timeline(reload: reload)
                guard !Task.isCancelled else { return }
                merge(points)
                if let first = points.first?.time.flooredToHour, let last = points.last?.time.flooredToHour {
                    loadedHourRanges.append(first...last)
                }
                timelineFailed = false
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                timelineFailed = timelineByHour.isEmpty
            }
        }
    }

    private func ensureHourlyCoverage() {
        let window = window
        let latest = nowHour.addingHours(RhythmWindow.hoursForward)
        let lower = window.startHour
        let upper = min(window.endHour, latest)
        guard !loadedHourRanges.contains(where: { $0.lowerBound <= lower && $0.upperBound >= upper }) else { return }
        let from = window.startHour.addingHours(-24)
        let to = min(window.endHour.addingHours(24), latest)
        guard from < to else { return }
        rangeTask?.cancel()
        rangeTask = Task { [source] in
            do {
                let points = try await source.timeline(from: from, to: to)
                guard !Task.isCancelled else { return }
                merge(points)
                loadedHourRanges.append(from...to)
            } catch {
                return
            }
        }
    }

    private func ensureYear(_ year: Int, reload: Bool = false) {
        let isCurrent = year == DutchFormat.year(nowHour)
        let isFresh: Bool = {
            guard let loaded = yearLoadedAt[year] else { return false }
            return !isCurrent || clock().timeIntervalSince(loaded) < 3600
        }()
        if !reload, isFresh { return }
        guard yearTasks[year] == nil else { return }
        if yearLoadedAt[year] == nil { loadingYears.insert(year) }
        failedYears.remove(year)
        yearTasks[year] = Task { [source] in
            do {
                let data = try await source.year(year, reload: reload)
                sourceMeta = data.sources
                var index = daysByDate
                for point in data.days {
                    index[point.day] = point
                }
                daysByDate = index
                yearLoadedAt[year] = clock()
            } catch is CancellationError {
            } catch {
                failedYears.insert(year)
            }
            loadingYears.remove(year)
            yearTasks[year] = nil
        }
    }

    private func loadFocus(reload: Bool) {
        mixTask?.cancel()
        let hour = focusHour
        mixError = nil

        if !reload, let cached = mixCache[hour] {
            displayedMix = cached
            isLoadingMix = false
            mixTask = nil
        } else {
            isLoadingMix = true
            mixTask = Task { await fetchMix(hour: hour, reload: reload) }
        }
        loadStory(reload: reload)
    }

    private func loadDayFocus(reload: Bool) {
        ensureYear(DutchFormat.year(focusDay), reload: reload)
        loadStory(reload: reload)
    }

    private var storyKey: StoryKey {
        scale == .day ? .hour(focusHour) : .day(focusDay)
    }

    private func loadStory(reload: Bool) {
        storyTask?.cancel()
        let key = storyKey
        if !reload, let cached = storyCache[key] {
            story = cached
            storyPhase = .ready
            storyTask = nil
            return
        }
        story = ""
        storyPhase = .loading
        storyTask = Task { await fetchStory(key: key, reload: reload) }
    }

    private func fetchMix(hour: Date, reload: Bool) async {
        do {
            let received = try await source.mix(at: hour, reload: reload)
            guard !Task.isCancelled, hour == focusHour else { return }
            let mix = received.hour == hour ? received : Mix(focusTime: hour, greenPct: 0, totalKWh: 0, sources: [])
            mixCache[hour] = mix
            displayedMix = mix
            isLoadingMix = false
            if hour == nowHour, mix.hasData, lastWidgetReloadHour != hour {
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

    private func fetchStory(key: StoryKey, reload: Bool) async {
        let stream: AsyncThrowingStream<String, Error>
        switch key {
        case .hour(let hour): stream = source.story(at: hour, reload: reload)
        case .day(let day): stream = source.dayStory(day, reload: reload)
        }
        var latest = ""
        do {
            for try await partial in stream {
                guard !Task.isCancelled, key == storyKey else { return }
                latest = partial
                story = partial
                storyPhase = .streaming
            }
            guard !Task.isCancelled, key == storyKey else { return }
            let text = latest.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                story = ""
                storyPhase = .unavailable
            } else {
                story = text
                storyCache[key] = text
                storyPhase = .ready
            }
        } catch {
            guard !Task.isCancelled, key == storyKey else { return }
            story = ""
            storyPhase = .unavailable
        }
    }
}
