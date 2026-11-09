import CoreGraphics
import Foundation
import Testing
@testable import Stroompeil

struct RhythmWindowTests {
    private let now = ISODate.parse("2026-11-09T14:00:00Z")!

    @Test func defaultWindowSpansTwoDaysBackAndOneDayForward() {
        let window = RhythmWindow(nowHour: now, offset: 0)
        #expect(window.count == 73)
        #expect(window.nowIndex == 48)
        #expect(window.startHour == now.addingHours(-48))
        #expect(window.endHour == now.addingHours(24))
        #expect(window.hour(at: 0) == window.startHour)
        #expect(window.index(of: now.addingHours(25)) == nil)
        #expect(window.index(of: now.addingTimeInterval(30 * 60)) == 48)
    }

    @Test func clampKeepsHourInsideWindow() {
        let window = RhythmWindow(nowHour: now, offset: 0)
        #expect(window.clamp(now.addingHours(100)) == window.endHour)
        #expect(window.clamp(now.addingHours(-100)) == window.startHour)
        #expect(window.clamp(now.addingHours(3)) == now.addingHours(3))
    }

    @Test func panningForwardStopsAtNow() {
        let window = RhythmWindow(nowHour: now, offset: 0)
        #expect(window.canPanForward == false)
        let shifted = RhythmWindow(nowHour: now, offset: -30)
        #expect(shifted.canPanForward)
        #expect(shifted.offsetAfterPanForward == -6)
        #expect(RhythmWindow(nowHour: now, offset: -6).offsetAfterPanForward == 0)
    }

    @Test func panningBackStopsAtEarliestData() {
        let earliest = now.addingHours(-719)
        let window = RhythmWindow(nowHour: now, offset: 0)
        #expect(window.canPanBack(earliest: earliest))
        #expect(window.offsetAfterPanBack(earliest: earliest) == -24)

        let nearEdge = RhythmWindow(nowHour: now, offset: -660)
        #expect(nearEdge.offsetAfterPanBack(earliest: earliest) == -671)
        let atEdge = RhythmWindow(nowHour: now, offset: -671)
        #expect(atEdge.startHour == earliest)
        #expect(atEdge.canPanBack(earliest: earliest) == false)
    }

    @Test func cannotPanBackWhenDataStartsInsideWindow() {
        let window = RhythmWindow(nowHour: now, offset: 0)
        #expect(window.canPanBack(earliest: now.addingHours(-10)) == false)
    }

    @Test func barLayoutMapsTouchesToBars() {
        let layout = BarLayout(width: 353, count: 73)
        #expect(layout.index(at: -20) == 0)
        #expect(layout.index(at: 0) == 0)
        #expect(layout.index(at: 353) == 72)
        #expect(layout.index(at: 999) == 72)
        for index in 0..<73 {
            #expect(layout.index(at: layout.centerX(index)) == index)
        }
        #expect(abs(layout.minX(72) + layout.barWidth - 353) < 0.001)
    }
}
