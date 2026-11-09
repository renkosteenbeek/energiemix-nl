import SwiftUI

struct PeriodChart: View {
    let model: DashboardModel
    @Binding var scrubDay: Date?
    let onZoom: (TimeScale, Date?) -> Void

    @State private var tapCount = 0

    var body: some View {
        let window = model.periodWindow
        let today = model.today
        let bars = makeBars(window, today: today)
        let focusIndex = window.index(of: scrubDay ?? model.focusDay)
        let todayIndex = window.index(of: today)
        let months = window.isYear ? window.monthSummaries(days: model.history.days) : []
        let focusMonthStart = focusIndex.flatMap { index in months.first { $0.contains(index) } }?.startIndex

        GeometryReader { proxy in
            let layout = BarLayout(width: proxy.size.width, count: bars.count, gap: window.isYear ? 0 : 2)
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: ChartMetrics.touchSlop)
                ZStack(alignment: .topLeading) {
                    BarCanvas(
                        bars: bars,
                        layout: layout,
                        usage: window.isYear ? nil : .fromMinimum,
                        months: months,
                        focusMonthStart: focusMonthStart
                    )
                    ChartMarkers(layout: layout, currentIndex: todayIndex, focusIndex: focusIndex)
                }
                .frame(width: layout.width, height: ChartMetrics.plotHeight, alignment: .topLeading)
                .allowsHitTesting(false)
                ChartRule()
                if window.isYear {
                    MonthAxis(layout: layout, months: months, focusMonthStart: focusMonthStart)
                } else {
                    AxisMarks(layout: layout, marks: mondays(window), currentIndex: todayIndex)
                }
            }
            .overlay {
                ScrubSurface(
                    onTap: { x in
                        tapCount += 1
                        model.selectDay(window.day(at: layout.index(at: x)))
                    },
                    onScrub: { x in
                        scrubDay = min(window.day(at: layout.index(at: x)), today)
                    },
                    onScrubEnd: { x in
                        if let x { model.selectDay(window.day(at: layout.index(at: x))) }
                        scrubDay = nil
                    },
                    onPinch: { zoomIn, x in
                        let day = min(window.day(at: layout.index(at: x)), today)
                        if zoomIn, let finer = model.scale.finer {
                            onZoom(finer, day)
                        } else if !zoomIn, let coarser = model.scale.coarser {
                            onZoom(coarser, nil)
                        }
                    }
                )
            }
        }
        .sensoryFeedback(trigger: scrubDay) { old, new in
            guard let new else { return nil }
            guard let old else { return .impact(weight: .medium) }
            if window.isYear {
                return DutchFormat.calendar.isDate(old, equalTo: new, toGranularity: .month) ? nil : .selection
            }
            return old == new ? nil : .selection
        }
        .sensoryFeedback(.selection, trigger: tapCount)
        .accessibilityElement()
        .accessibilityLabel(window.isYear ? "Tijdlijn per dag over \(window.title)" : "Tijdlijn per dag in \(window.title)")
        .accessibilityValue(spokenValue(for: model.focusDay, window: window, months: months))
        .accessibilityHint("Veeg omhoog of omlaag om een andere dag te kiezen.")
        .ignoresAccessibilityActivation()
        .accessibilityActions {
            if let finer = model.scale.finer {
                Button("Inzoomen") { onZoom(finer, nil) }
            }
            if let coarser = model.scale.coarser {
                Button("Uitzoomen") { onZoom(coarser, nil) }
            }
        }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.step(by: 1)
            case .decrement: model.step(by: -1)
            @unknown default: break
            }
        }
    }

    private func makeBars(_ window: PeriodWindow, today: Date) -> [ChartBar] {
        (0..<window.count).map { index in
            let day = window.day(at: index)
            let point = model.history.days[day]
            return ChartBar(
                index: index,
                greenPct: point?.greenPct,
                totalKWh: point?.totalKWh,
                isProvisional: day == today,
                isFuture: day > today,
                isCurrent: day == today
            )
        }
    }

    private func mondays(_ window: PeriodWindow) -> [AxisMark] {
        let calendar = DutchFormat.calendar
        return (0..<window.count).compactMap { index in
            let day = window.day(at: index)
            guard calendar.component(.weekday, from: day) == 2 else { return nil }
            return AxisMark(index: index, text: String(calendar.component(.day, from: day)))
        }
    }

    private func spokenValue(for day: Date, window: PeriodWindow, months: [MonthSummary]) -> String {
        var parts = [DutchFormat.dayLong(day, now: model.nowHour)]
        if let point = model.history.days[day] {
            parts.append("\(DutchFormat.percentSpoken(point.greenPct)) duurzaam")
            parts.append("\(DutchFormat.gigawattHoursSpoken(point.totalKWh)) verbruik")
            if day == model.today { parts.append("voorlopig") }
        } else {
            parts.append("geen gegevens")
        }
        if let index = window.index(of: day),
           let month = months.first(where: { $0.contains(index) }),
           let average = month.average {
            parts.append("\(DutchFormat.monthTitle(month.month)) gemiddeld \(DutchFormat.percentSpoken(average))")
        }
        return parts.joined(separator: ", ")
    }
}
