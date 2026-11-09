import CoreGraphics
import Foundation

struct RhythmWindow: Equatable, Sendable {
    static let hoursBack = 48
    static let hoursForward = 24
    static let panStep = 24
    static let maxHoursBack = 720

    let nowHour: Date
    let offset: Int

    var startOffset: Int { -Self.hoursBack + offset }
    var endOffset: Int { min(Self.hoursForward + offset, Self.hoursForward) }
    var count: Int { endOffset - startOffset + 1 }
    var startHour: Date { nowHour.addingHours(startOffset) }
    var endHour: Date { nowHour.addingHours(endOffset) }

    func hour(at index: Int) -> Date {
        nowHour.addingHours(startOffset + index)
    }

    func index(of hour: Date) -> Int? {
        let index = startHour.hours(until: hour.flooredToHour)
        return (0..<count).contains(index) ? index : nil
    }

    var nowIndex: Int? { index(of: nowHour) }

    func clamp(_ hour: Date) -> Date {
        min(max(hour.flooredToHour, startHour), endHour)
    }

    func earliestOffset(earliest: Date) -> Int {
        let earliestFromNow = nowHour.hours(until: earliest.flooredToHour)
        return min(0, earliestFromNow + Self.hoursBack)
    }

    func canPanBack(earliest: Date) -> Bool {
        offset > earliestOffset(earliest: earliest)
    }

    var canPanForward: Bool { offset < 0 }

    func offsetAfterPanBack(earliest: Date) -> Int {
        max(offset - Self.panStep, earliestOffset(earliest: earliest))
    }

    var offsetAfterPanForward: Int {
        min(offset + Self.panStep, 0)
    }
}

struct BarLayout: Equatable {
    let width: CGFloat
    let count: Int
    var gap: CGFloat = 1.5

    var barWidth: CGFloat {
        guard count > 0 else { return 0 }
        return max(0.5, (width - gap * CGFloat(count - 1)) / CGFloat(count))
    }

    var stride: CGFloat { barWidth + gap }

    func minX(_ index: Int) -> CGFloat {
        CGFloat(index) * stride
    }

    func centerX(_ index: Int) -> CGFloat {
        minX(index) + barWidth / 2
    }

    func index(at x: CGFloat) -> Int {
        guard count > 0, stride > 0 else { return 0 }
        let raw = Int((x / stride).rounded(.down))
        return min(max(raw, 0), count - 1)
    }
}
