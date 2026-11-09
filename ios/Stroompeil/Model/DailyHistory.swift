import Foundation
import Observation

@MainActor
@Observable
final class DailyHistory {
    private(set) var days: [Date: DayPoint] = [:]
    private(set) var sources: [SourceMeta] = []
    private(set) var loadingYears: Set<Int> = []
    private(set) var failedYears: Set<Int> = []

    @ObservationIgnored private let source: any EnergyDataSource
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var loadedAt: [Int: Date] = [:]
    @ObservationIgnored private var tasks: [Int: Task<Void, Never>] = [:]

    init(source: any EnergyDataSource, clock: @escaping @Sendable () -> Date) {
        self.source = source
        self.clock = clock
    }

    func isLoaded(_ year: Int) -> Bool {
        loadedAt[year] != nil
    }

    func snapshot(for day: Date) -> Snapshot? {
        if let point = days[day] {
            return Snapshot(day: point, sources: sources)
        }
        guard isLoaded(DutchFormat.year(day)) else { return nil }
        return Snapshot(day: DayPoint(day: day, totalKWh: 0, greenPct: 0, volumes: []), sources: sources)
    }

    @discardableResult
    func ensure(_ year: Int, reload: Bool = false) -> Task<Void, Never>? {
        if !reload, isFresh(year) { return nil }
        if let running = tasks[year] { return running }
        if !isLoaded(year) { loadingYears.insert(year) }
        failedYears.remove(year)
        let task = Task { [source] in
            do {
                let data = try await source.year(year, reload: reload)
                sources = data.sources
                var index = days
                for point in data.days {
                    index[point.day] = point
                }
                days = index
                loadedAt[year] = clock()
            } catch is CancellationError {
            } catch {
                failedYears.insert(year)
            }
            loadingYears.remove(year)
            tasks[year] = nil
        }
        tasks[year] = task
        return task
    }

    private func isFresh(_ year: Int) -> Bool {
        guard let loaded = loadedAt[year] else { return false }
        let now = clock()
        let currentYear = DutchFormat.year(now)
        let dayOfYear = DutchFormat.calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let isSettling = year == currentYear || (year == currentYear - 1 && dayOfYear <= 3)
        return !isSettling || now.timeIntervalSince(loaded) < 3600
    }
}
