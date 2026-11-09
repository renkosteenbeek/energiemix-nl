import CoreGraphics
import Foundation

enum TimeScale: Int, CaseIterable, Comparable, Sendable {
    case day
    case month
    case year

    var title: String {
        switch self {
        case .day: "Dag"
        case .month: "Maand"
        case .year: "Jaar"
        }
    }

    var finer: TimeScale? { TimeScale(rawValue: rawValue - 1) }
    var coarser: TimeScale? { TimeScale(rawValue: rawValue + 1) }

    static func < (lhs: TimeScale, rhs: TimeScale) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct PeriodWindow: Equatable, Sendable {
    static let earliestDay = DutchFormat.day(fromISO: "2021-01-01")!

    let scale: TimeScale
    let anchor: Date
    let today: Date

    init(scale: TimeScale, anchor: Date, today: Date) {
        self.scale = scale == .year ? .year : .month
        self.anchor = DutchFormat.startOfDay(anchor)
        self.today = DutchFormat.startOfDay(today)
    }

    var isYear: Bool { scale == .year }

    private var calendar: Calendar { DutchFormat.calendar }
    private var component: Calendar.Component { isYear ? .year : .month }

    var start: Date {
        calendar.dateInterval(of: component, for: anchor)?.start ?? anchor
    }

    var end: Date {
        let next = calendar.date(byAdding: component, value: 1, to: start) ?? start
        return DutchFormat.addingDays(-1, to: next)
    }

    var count: Int {
        (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    var title: String {
        isYear ? String(DutchFormat.year(start)) : DutchFormat.monthTitle(start)
    }

    func day(at index: Int) -> Date {
        DutchFormat.addingDays(index, to: start)
    }

    func index(of day: Date) -> Int? {
        let offset = calendar.dateComponents([.day], from: start, to: DutchFormat.startOfDay(day)).day ?? -1
        return (0..<count).contains(offset) ? offset : nil
    }

    func fraction(of day: Date) -> CGFloat {
        index(of: day).map { (CGFloat($0) + 0.5) / CGFloat(count) } ?? 0.5
    }

    var canGoBack: Bool { start > Self.earliestDay }
    var canGoForward: Bool { end < today }

    func anchorShifted(by periods: Int) -> Date {
        let shifted = calendar.date(byAdding: component, value: periods, to: anchor) ?? anchor
        return Self.clamp(shifted, today: today)
    }

    static func clamp(_ day: Date, today: Date) -> Date {
        min(max(DutchFormat.startOfDay(day), earliestDay), DutchFormat.startOfDay(today))
    }
}

struct MonthSummary: Equatable, Identifiable {
    let month: Date
    let startIndex: Int
    let endIndex: Int
    let average: Double?

    var id: Int { startIndex }

    func contains(_ index: Int) -> Bool {
        (startIndex...endIndex).contains(index)
    }
}

extension PeriodWindow {
    func monthSummaries(days: [Date: DayPoint]) -> [MonthSummary] {
        var summaries: [MonthSummary] = []
        var monthStart = start
        while monthStart <= end {
            let next = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? end
            let monthEnd = min(DutchFormat.addingDays(-1, to: next), end)
            guard let startIndex = index(of: monthStart), let endIndex = index(of: monthEnd) else { break }
            let points = (startIndex...endIndex).compactMap { days[day(at: $0)] }
            summaries.append(MonthSummary(
                month: monthStart,
                startIndex: startIndex,
                endIndex: endIndex,
                average: PeriodStats(days: points)?.average
            ))
            monthStart = next
        }
        return summaries
    }
}

struct PeriodStats: Equatable {
    let average: Double
    let greenest: DayPoint
    let greyest: DayPoint

    init?(days: [DayPoint]) {
        let measured = days.filter { $0.totalKWh > 0 }
        guard let greenest = measured.max(by: { $0.greenPct < $1.greenPct }),
              let greyest = measured.min(by: { $0.greenPct < $1.greenPct })
        else { return nil }
        let total = measured.reduce(0) { $0 + $1.totalKWh }
        let green = measured.reduce(0) { $0 + $1.totalKWh * $1.greenPct / 100 }
        average = total > 0 ? green / total * 100 : 0
        self.greenest = greenest
        self.greyest = greyest
    }
}
