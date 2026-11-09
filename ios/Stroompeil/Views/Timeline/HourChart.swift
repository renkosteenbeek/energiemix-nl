import SwiftUI

struct HourChart: View {
    let model: DashboardModel
    @Binding var scrubHour: Date?
    let onZoom: (TimeScale, Date?) -> Void

    @State private var tapCount = 0

    var body: some View {
        let window = model.window
        let bars = makeBars(window)
        let focusIndex = window.index(of: scrubHour ?? model.focusHour)

        GeometryReader { proxy in
            let layout = BarLayout(width: proxy.size.width, count: bars.count)
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: ChartMetrics.touchSlop)
                ZStack(alignment: .topLeading) {
                    ForecastShade(bars: bars, layout: layout)
                    BarCanvas(bars: bars, layout: layout, usage: .fromZero)
                    ChartMarkers(layout: layout, currentIndex: window.nowIndex, focusIndex: focusIndex)
                }
                .frame(width: layout.width, height: ChartMetrics.plotHeight, alignment: .topLeading)
                .allowsHitTesting(false)
                ChartRule()
                AxisMarks(layout: layout, marks: dayStarts(window), currentIndex: window.nowIndex)
            }
            .overlay {
                ScrubSurface(
                    onTap: { x in
                        tapCount += 1
                        model.select(window.hour(at: layout.index(at: x)))
                    },
                    onScrub: { x in
                        scrubHour = window.hour(at: layout.index(at: x))
                    },
                    onScrubEnd: { x in
                        if let x { model.select(window.hour(at: layout.index(at: x))) }
                        scrubHour = nil
                    },
                    onPinch: { zoomIn, _ in
                        if !zoomIn, let coarser = model.scale.coarser { onZoom(coarser, nil) }
                    }
                )
            }
        }
        .sensoryFeedback(trigger: scrubHour) { old, new in
            switch (old, new) {
            case (nil, .some): .impact(weight: .medium)
            case (.some(let a), .some(let b)) where a != b: .selection
            default: nil
            }
        }
        .sensoryFeedback(.selection, trigger: tapCount)
        .accessibilityElement()
        .accessibilityLabel("Tijdlijn per uur")
        .accessibilityValue(spokenValue(for: model.focusHour))
        .accessibilityHint("Veeg omhoog of omlaag om een ander uur te kiezen.")
        .ignoresAccessibilityActivation()
        .accessibilityActions {
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

    private func makeBars(_ window: RhythmWindow) -> [ChartBar] {
        (0..<window.count).map { index in
            let hour = window.hour(at: index)
            let point = model.hourly.points[hour]
            return ChartBar(
                index: index,
                greenPct: point?.greenPct,
                totalKWh: point?.totalKWh,
                isProvisional: hour > model.nowHour,
                isFuture: hour > model.nowHour,
                isCurrent: hour == model.nowHour
            )
        }
    }

    private func dayStarts(_ window: RhythmWindow) -> [AxisMark] {
        (0..<window.count).compactMap { index in
            let hour = window.hour(at: index)
            guard DutchFormat.amsterdamHour(hour) == 0 else { return nil }
            return AxisMark(index: index, text: DutchFormat.weekdayShort(hour).uppercased())
        }
    }

    private func spokenValue(for hour: Date) -> String {
        var parts = [DutchFormat.long(hour)]
        if let point = model.hourly.points[hour] {
            parts.append("\(DutchFormat.percentSpoken(point.greenPct)) duurzaam")
            if point.totalKWh > 0 {
                parts.append("\(DutchFormat.gigawattHoursSpoken(point.totalKWh)) verbruik")
            }
        }
        if hour > model.nowHour {
            parts.append("verwachting")
        }
        return parts.joined(separator: ", ")
    }
}

private struct ForecastShade: View {
    let bars: [ChartBar]
    let layout: BarLayout

    var body: some View {
        if let index = bars.first(where: \.isFuture)?.index {
            let x = max(0, layout.minX(index) - layout.gap / 2)
            let width = max(0, layout.width - x)
            Rectangle()
                .fill(Palette.forecastShade)
                .frame(width: width, height: ChartMetrics.plotHeight)
                .offset(x: x)
            Text(verbatim: "VERWACHTING")
                .font(.system(size: 9))
                .tracking(1.6)
                .foregroundStyle(Palette.dim2)
                .fixedSize()
                .offset(x: x + 4, y: 2)
                .opacity(width > 84 ? 1 : 0)
        }
    }
}
