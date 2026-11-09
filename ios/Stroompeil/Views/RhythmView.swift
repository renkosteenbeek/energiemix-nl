import SwiftUI

struct RhythmBar: Identifiable {
    let index: Int
    let hour: Date
    let greenPct: Double?
    let totalKWh: Double?
    let isForecast: Bool
    let isNow: Bool

    var id: Int { index }
}

struct RhythmView: View {
    let model: DashboardModel

    @State private var scrubHour: Date?
    @State private var tapCount = 0
    @ScaledMetric(relativeTo: .footnote) private var previewSize: CGFloat = 13

    private let chartHeight: CGFloat = 96
    private let axisHeight: CGFloat = 22

    var body: some View {
        let window = model.window
        let bars = makeBars(window: window)
        let effectiveHour = scrubHour ?? model.focusHour

        VStack(alignment: .leading, spacing: 0) {
            header(hour: effectiveHour)
                .padding(.bottom, 16)
            chart(window: window, bars: bars, effectiveHour: effectiveHour)
            if model.timelineFailed {
                HStack(spacing: 12) {
                    Text("Het dagritme kon niet worden geladen.")
                        .foregroundStyle(Palette.dim)
                    Button("Opnieuw", action: model.retryTimeline)
                        .fontWeight(.medium)
                        .foregroundStyle(Palette.ink)
                }
                .font(.footnote)
                .padding(.top, 4)
            }
        }
    }

    private func makeBars(window: RhythmWindow) -> [RhythmBar] {
        (0..<window.count).map { index in
            let hour = window.hour(at: index)
            let point = model.timelineByHour[hour]
            return RhythmBar(
                index: index,
                hour: hour,
                greenPct: point?.greenPct,
                totalKWh: point?.totalKWh,
                isForecast: hour > model.nowHour,
                isNow: hour == model.nowHour
            )
        }
    }

    private func header(hour: Date) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Dagritme", bottomPadding: 0)
                previewLine(hour: hour)
                    .font(.system(size: previewSize))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                CircleControl(enabled: !model.isAtNow, accessibilityLabel: "Terug naar nu", action: model.jumpToNow) {
                    Text("NU")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.2)
                }
                .opacity(model.isAtNow ? 0 : 1)
                .accessibilityHidden(model.isAtNow)
                .animation(.easeInOut(duration: 0.25), value: model.isAtNow)

                CircleControl(enabled: model.canPanBack, accessibilityLabel: "Dag eerder", action: model.panBack) {
                    Image(systemName: "chevron.left.2")
                        .font(.system(size: 11, weight: .semibold))
                }
                CircleControl(enabled: model.canPanForward, accessibilityLabel: "Dag later", action: model.panForward) {
                    Image(systemName: "chevron.right.2")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
        }
    }

    private func previewLine(hour: Date) -> Text {
        let separator = Text(verbatim: " · ").foregroundStyle(Palette.dim2)
        var line = Text(verbatim: DutchFormat.compact(hour)).foregroundStyle(Palette.ink)
        let point = model.timelineByHour[hour]
        if let point {
            let pct = Text(verbatim: DutchFormat.percent(point.greenPct))
                .fontWeight(.medium)
                .foregroundStyle(GreenBand(percentage: point.greenPct).labelColor)
            line = Text("\(line)\(separator)\(pct)")
            if point.totalKWh > 0 {
                let usage = Text(verbatim: DutchFormat.gigawattHours(point.totalKWh)).foregroundStyle(Palette.dim)
                line = Text("\(line)\(separator)\(usage)")
            }
        }
        if hour > model.nowHour {
            let badge = Text(verbatim: "  FORECAST")
                .font(.system(size: 9))
                .tracking(1.6)
                .foregroundStyle(Palette.dim2)
            line = Text("\(line)\(badge)")
        }
        return line.monospacedDigit()
    }

    private func chart(window: RhythmWindow, bars: [RhythmBar], effectiveHour: Date) -> some View {
        GeometryReader { proxy in
            let layout = BarLayout(width: proxy.size.width, count: bars.count)
            VStack(alignment: .leading, spacing: 0) {
                RhythmPlot(
                    bars: bars,
                    layout: layout,
                    focusIndex: window.index(of: effectiveHour),
                    nowIndex: window.nowIndex,
                    height: chartHeight
                )
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
                        }
                    )
                }

                Rectangle()
                    .fill(Palette.rule2)
                    .frame(height: 1)
                    .padding(.top, 8)

                RhythmAxis(bars: bars, layout: layout, nowIndex: window.nowIndex, height: axisHeight)
            }
        }
        .frame(height: chartHeight + 9 + axisHeight)
        .sensoryFeedback(trigger: scrubHour) { old, new in
            switch (old, new) {
            case (nil, .some): .impact(weight: .medium)
            case (.some(let a), .some(let b)) where a != b: .selection
            default: nil
            }
        }
        .sensoryFeedback(.selection, trigger: tapCount)
        .accessibilityElement()
        .accessibilityLabel("Dagritme")
        .accessibilityValue(spokenValue(for: model.focusHour))
        .accessibilityHint("Veeg omhoog of omlaag om een ander uur te kiezen.")
        .accessibilityAction {}
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.step(by: 1)
            case .decrement: model.step(by: -1)
            @unknown default: break
            }
        }
    }

    private func spokenValue(for hour: Date) -> String {
        var parts = [DutchFormat.long(hour)]
        if let point = model.timelineByHour[hour] {
            parts.append("\(Int(point.greenPct.rounded())) procent duurzaam")
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

private struct RhythmPlot: View {
    let bars: [RhythmBar]
    let layout: BarLayout
    let focusIndex: Int?
    let nowIndex: Int?
    let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            forecastShade
            canvas
            nowLine
            indicator
        }
        .frame(width: layout.width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var forecastStartX: CGFloat? {
        guard let index = bars.first(where: \.isForecast)?.index else { return nil }
        return max(0, layout.minX(index) - BarLayout.gap / 2)
    }

    @ViewBuilder
    private var forecastShade: some View {
        if let x = forecastStartX {
            let width = max(0, layout.width - x)
            Rectangle()
                .fill(Palette.forecastShade)
                .frame(width: width, height: height)
                .offset(x: x)
            Text(verbatim: "FORECAST")
                .font(.system(size: 9))
                .tracking(1.6)
                .foregroundStyle(Palette.dim2)
                .fixedSize()
                .offset(x: x + 4, y: 2)
                .opacity(width > 60 ? 1 : 0)
        }
    }

    @ViewBuilder
    private var nowLine: some View {
        if let nowIndex {
            Rectangle()
                .fill(Palette.ink.opacity(0.35))
                .frame(width: 1, height: height)
                .offset(x: layout.centerX(nowIndex) - 0.5)
        }
    }

    @ViewBuilder
    private var indicator: some View {
        if let focusIndex {
            FocusIndicator()
                .frame(height: height + 14)
                .offset(x: layout.centerX(focusIndex) - FocusIndicator.width / 2, y: -10)
                .animation(.easeOut(duration: 0.15), value: focusIndex)
        }
    }

    private var canvas: some View {
        let bars = bars
        let layout = layout
        return Canvas { context, size in
            Self.drawBars(bars, layout: layout, in: &context, size: size)
            Self.drawUsageLine(bars, layout: layout, in: &context, size: size)
        }
        .frame(width: layout.width, height: height)
        .id(colorScheme)
    }

    private static func drawBars(_ bars: [RhythmBar], layout: BarLayout, in context: inout GraphicsContext, size: CGSize) {
        for bar in bars {
            let barHeight: CGFloat
            let color: Color
            if let pct = bar.greenPct {
                barHeight = max(6, CGFloat(pct) / 100 * size.height)
                color = GreenBand(percentage: pct).color.opacity(bar.isForecast ? 0.88 : 1)
            } else {
                barHeight = 6
                color = Palette.emptyBar
            }
            let rect = CGRect(x: layout.minX(bar.index), y: size.height - barHeight, width: layout.barWidth, height: barHeight)
            context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
        }
    }

    private static func drawUsageLine(_ bars: [RhythmBar], layout: BarLayout, in context: inout GraphicsContext, size: CGSize) {
        var points: [(index: Int, kWh: Double)] = []
        for bar in bars {
            if let kWh = bar.totalKWh, kWh > 0, !bar.isNow {
                points.append((bar.index, kWh))
            }
        }
        guard points.count >= 2, let peak = points.map(\.kWh).max(), peak > 0 else { return }
        var path = Path()
        for (offset, point) in points.enumerated() {
            let location = CGPoint(x: layout.centerX(point.index), y: (1 - CGFloat(point.kWh / peak)) * size.height)
            if offset == 0 {
                path.move(to: location)
            } else {
                path.addLine(to: location)
            }
        }
        context.stroke(
            path,
            with: .color(Palette.ink.opacity(0.45)),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
        )
    }
}

private struct RhythmAxis: View {
    let bars: [RhythmBar]
    let layout: BarLayout
    let nowIndex: Int?
    let height: CGFloat

    private var nowX: CGFloat? { nowIndex.map { layout.centerX($0) } }

    private var dayMarks: [(id: Int, x: CGFloat, text: String)] {
        bars.compactMap { bar in
            guard DutchFormat.amsterdamHour(bar.hour) == 0 else { return nil }
            let x = layout.centerX(bar.index)
            if let nowX, abs(nowX - x) <= 26 { return nil }
            return (bar.index, x, DutchFormat.weekdayShort(bar.hour).uppercased())
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(dayMarks, id: \.id) { mark in
                AxisLabel(text: mark.text, isEmphasized: false)
                    .position(x: clamped(mark.x), y: height / 2 + 2)
            }
            if let nowX {
                AxisLabel(text: "NU", isEmphasized: true)
                    .position(x: clamped(nowX), y: height / 2 + 2)
            }
        }
        .frame(width: layout.width, height: height)
        .accessibilityHidden(true)
    }

    private func clamped(_ x: CGFloat) -> CGFloat {
        min(max(x, 10), layout.width - 10)
    }
}

private struct ScrubSurface: UIViewRepresentable {
    let onTap: (CGFloat) -> Void
    let onScrub: (CGFloat) -> Void
    let onScrubEnd: (CGFloat?) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.surface = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(surface: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var surface: ScrubSurface

        init(surface: ScrubSurface) {
            self.surface = surface
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            surface.onTap(recognizer.location(in: recognizer.view).x)
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let x = recognizer.location(in: recognizer.view).x
            switch recognizer.state {
            case .began, .changed: surface.onScrub(x)
            case .ended: surface.onScrubEnd(x)
            case .cancelled, .failed: surface.onScrubEnd(nil)
            default: break
            }
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

private struct AxisLabel: View {
    let text: String
    let isEmphasized: Bool

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 9, weight: isEmphasized ? .semibold : .regular))
            .tracking(1.2)
            .foregroundStyle(isEmphasized ? Palette.ink : Palette.dim2)
            .fixedSize()
    }
}

private struct FocusIndicator: View {
    static let width: CGFloat = 8

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Palette.ink)
                .frame(width: 2)
            RoundedRectangle(cornerRadius: 1)
                .fill(Palette.ink)
                .frame(width: 7, height: 7)
                .rotationEffect(.degrees(45))
                .offset(y: -3)
        }
        .frame(width: Self.width)
    }
}

struct CircleControl<Label: View>: View {
    let enabled: Bool
    let accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .foregroundStyle(Palette.ink)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Palette.rule, lineWidth: 1))
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(accessibilityLabel)
    }
}
