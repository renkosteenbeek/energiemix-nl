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

@MainActor
@Observable
final class DashboardModel {
    private(set) var nowHour: Date
    private(set) var focusHour: Date
    private(set) var windowOffset = 0
    private(set) var timeline: [TimePoint] = []
    private(set) var timelineByHour: [Date: TimePoint] = [:]
    private(set) var timelineFailed = false
    private(set) var displayedMix: Mix?
    private(set) var isLoadingMix = false
    private(set) var mixError: String?
    private(set) var story = ""
    private(set) var storyPhase: StoryPhase = .idle

    @ObservationIgnored private let source: any EnergyDataSource
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private let reloadWidgets: @MainActor () -> Void
    @ObservationIgnored private var mixCache: [Date: Mix] = [:]
    @ObservationIgnored private var storyCache: [Date: String] = [:]
    @ObservationIgnored private var mixTask: Task<Void, Never>?
    @ObservationIgnored private var storyTask: Task<Void, Never>?
    @ObservationIgnored private var timelineTask: Task<Void, Never>?
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
    }

    var window: RhythmWindow { RhythmWindow(nowHour: nowHour, offset: windowOffset) }
    var isAtNow: Bool { focusHour == nowHour && windowOffset == 0 }
    var earliestHour: Date { timeline.first?.time.flooredToHour ?? nowHour.addingHours(-RhythmWindow.maxHoursBack) }
    var canPanBack: Bool { window.canPanBack(earliest: earliestHour) }
    var canPanForward: Bool { window.canPanForward }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        loadTimeline(reload: false)
        loadFocus(reload: false)
    }

    func select(_ hour: Date) {
        let target = window.clamp(hour)
        guard target != focusHour else { return }
        focusHour = target
        loadFocus(reload: false)
    }

    func step(by hours: Int) {
        select(focusHour.addingHours(hours))
    }

    func jumpToNow() {
        clockTick()
        windowOffset = 0
        guard focusHour != nowHour else { return }
        focusHour = nowHour
        loadFocus(reload: false)
    }

    func panBack() {
        guard canPanBack else { return }
        apply(offset: window.offsetAfterPanBack(earliest: earliestHour))
    }

    func panForward() {
        guard canPanForward else { return }
        apply(offset: window.offsetAfterPanForward)
    }

    func retry() {
        if timeline.isEmpty { loadTimeline(reload: true) }
        loadFocus(reload: true)
    }

    func retryTimeline() {
        loadTimeline(reload: true)
    }

    func retryStory() {
        storyTask?.cancel()
        let hour = focusHour
        story = ""
        storyPhase = .loading
        storyTask = Task { await fetchStory(hour: hour, reload: true) }
    }

    func sceneBecameActive() {
        clockTick()
        guard hasStarted else { return }
        if timelineFailed {
            loadTimeline(reload: true)
        }
        if mixError != nil {
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
        loadFocus(reload: true)
        await timelineTask?.value
        await mixTask?.value
    }

    func clockTick() {
        let current = clock().flooredToHour
        guard current != nowHour else { return }
        let previous = nowHour
        let followNow = focusHour == previous && windowOffset == 0
        nowHour = current
        let settledBefore = previous.addingHours(-2)
        mixCache = mixCache.filter { $0.key < settledBefore }
        storyCache = storyCache.filter { $0.key < settledBefore }
        let target = followNow ? current : window.clamp(focusHour)
        let needsLoad = target != focusHour || mixCache[target] == nil
        focusHour = target
        guard hasStarted else { return }
        loadTimeline(reload: true)
        if needsLoad { loadFocus(reload: false) }
    }

    private func apply(offset newOffset: Int) {
        let delta = newOffset - windowOffset
        guard delta != 0 else { return }
        windowOffset = newOffset
        let target = window.clamp(focusHour.addingHours(delta))
        guard target != focusHour else { return }
        focusHour = target
        loadFocus(reload: false)
    }

    private func setTimeline(_ points: [TimePoint]) {
        timeline = points
        var index: [Date: TimePoint] = [:]
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
                setTimeline(points)
                timelineFailed = false
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                timelineFailed = timeline.isEmpty
            }
        }
    }

    private func loadFocus(reload: Bool) {
        mixTask?.cancel()
        storyTask?.cancel()
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

        if !reload, let cachedStory = storyCache[hour] {
            story = cachedStory
            storyPhase = .ready
            storyTask = nil
        } else {
            story = ""
            storyPhase = .loading
            storyTask = Task { await fetchStory(hour: hour, reload: reload) }
        }
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

    private func fetchStory(hour: Date, reload: Bool) async {
        var latest = ""
        do {
            for try await partial in source.story(at: hour, reload: reload) {
                guard !Task.isCancelled, hour == focusHour else { return }
                latest = partial
                story = partial
                storyPhase = .streaming
            }
            guard !Task.isCancelled, hour == focusHour else { return }
            let text = latest.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                story = ""
                storyPhase = .unavailable
            } else {
                story = text
                storyCache[hour] = text
                storyPhase = .ready
            }
        } catch {
            guard !Task.isCancelled, hour == focusHour else { return }
            story = ""
            storyPhase = .unavailable
        }
    }
}
