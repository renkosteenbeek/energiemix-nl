import Foundation
import Observation

@MainActor
@Observable
final class HourlySeries {
    private(set) var points: [Date: TimePoint] = [:]
    private(set) var failed = false

    @ObservationIgnored private let source: any EnergyDataSource
    @ObservationIgnored private var coverage: [ClosedRange<Date>] = []
    @ObservationIgnored private var recentTask: Task<Void, Never>?
    @ObservationIgnored private var rangeTask: Task<Void, Never>?

    init(source: any EnergyDataSource) {
        self.source = source
    }

    @discardableResult
    func loadRecent(reload: Bool) -> Task<Void, Never> {
        recentTask?.cancel()
        let task = Task { [source] in
            do {
                let loaded = try await source.timeline(reload: reload)
                guard !Task.isCancelled else { return }
                merge(loaded, covering: Self.span(of: loaded))
                failed = false
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                failed = points.isEmpty
            }
        }
        recentTask = task
        return task
    }

    func ensureCoverage(of window: RhythmWindow, until latest: Date) {
        let upper = min(window.endHour, latest)
        guard window.startHour < upper, !isCovered(window.startHour...upper) else { return }
        let from = window.startHour.addingHours(-24)
        let to = min(window.endHour.addingHours(24), latest)
        rangeTask?.cancel()
        rangeTask = Task { [source] in
            do {
                let loaded = try await source.timeline(from: from, to: to)
                guard !Task.isCancelled else { return }
                merge(loaded, covering: from...to)
            } catch {
                return
            }
        }
    }

    private func isCovered(_ range: ClosedRange<Date>) -> Bool {
        coverage.contains { $0.lowerBound <= range.lowerBound && $0.upperBound >= range.upperBound }
    }

    private func merge(_ loaded: [TimePoint], covering range: ClosedRange<Date>?) {
        if !loaded.isEmpty {
            var index = points
            for point in loaded {
                index[point.time.flooredToHour] = point
            }
            points = index
        }
        if let range { addCoverage(range) }
    }

    private func addCoverage(_ range: ClosedRange<Date>) {
        var merged = range
        var remaining: [ClosedRange<Date>] = []
        for existing in coverage {
            if existing.upperBound.addingHours(1) >= merged.lowerBound, merged.upperBound.addingHours(1) >= existing.lowerBound {
                merged = min(existing.lowerBound, merged.lowerBound)...max(existing.upperBound, merged.upperBound)
            } else {
                remaining.append(existing)
            }
        }
        coverage = remaining + [merged]
    }

    private static func span(of points: [TimePoint]) -> ClosedRange<Date>? {
        let hours = points.map { $0.time.flooredToHour }
        guard let lower = hours.min(), let upper = hours.max() else { return nil }
        return lower...upper
    }
}
