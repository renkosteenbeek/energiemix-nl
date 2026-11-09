import SwiftUI

enum ChartMetrics {
    static let plotHeight: CGFloat = 96
    static let axisHeight: CGFloat = 22
    static let monthAxisHeight: CGFloat = 36
    static let touchSlop: CGFloat = 14
    static let ruleSpacing: CGFloat = 8

    static func height(axis: CGFloat) -> CGFloat {
        touchSlop + plotHeight + ruleSpacing + 1 + axis
    }
}

struct ChartBar: Identifiable {
    let index: Int
    let greenPct: Double?
    let totalKWh: Double?
    let isProvisional: Bool
    let isFuture: Bool
    let isCurrent: Bool

    var id: Int { index }
}

enum UsageScale {
    case fromZero
    case fromMinimum
}

struct BarCanvas: View {
    let bars: [ChartBar]
    let layout: BarLayout
    var usage: UsageScale?
    var months: [MonthSummary] = []
    var focusMonthStart: Int?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let bars = bars
        let layout = layout
        let usage = usage
        let months = months
        let focusMonthStart = focusMonthStart
        Canvas { context, size in
            if months.isEmpty {
                Self.drawBars(bars, layout: layout, in: &context, size: size)
                if let usage {
                    Self.drawUsage(bars, layout: layout, scale: usage, in: &context, size: size)
                }
            } else {
                Self.drawTexture(bars, layout: layout, in: &context, size: size)
                Self.drawMonths(months, focusMonthStart: focusMonthStart, layout: layout, in: &context, size: size)
            }
        }
        .frame(width: layout.width, height: ChartMetrics.plotHeight)
        .id(colorScheme)
    }

    private static func drawBars(_ bars: [ChartBar], layout: BarLayout, in context: inout GraphicsContext, size: CGSize) {
        let overlap: CGFloat = layout.gap == 0 ? 0.6 : 0
        let radius: CGFloat = layout.gap == 0 ? 0 : 1
        for bar in bars {
            let barHeight: CGFloat
            let color: Color
            if let pct = bar.greenPct {
                barHeight = max(4, CGFloat(pct) / 100 * size.height)
                color = GreenBand(percentage: pct).color.opacity(bar.isProvisional ? 0.8 : 1)
            } else {
                barHeight = bar.isFuture ? 2 : 4
                color = Palette.emptyBar.opacity(bar.isFuture ? 0.6 : 1)
            }
            let rect = CGRect(x: layout.minX(bar.index), y: size.height - barHeight, width: layout.barWidth + overlap, height: barHeight)
            context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))
        }
    }

    private static func drawUsage(_ bars: [ChartBar], layout: BarLayout, scale: UsageScale, in context: inout GraphicsContext, size: CGSize) {
        let points = bars.compactMap { bar -> (index: Int, kWh: Double)? in
            guard let kWh = bar.totalKWh, kWh > 0, !bar.isCurrent else { return nil }
            return (bar.index, kWh)
        }
        guard points.count >= 2, let peak = points.map(\.kWh).max(), peak > 0 else { return }
        let lowest = points.map(\.kWh).min() ?? 0
        let floor: Double = scale == .fromZero ? 0 : lowest * 0.85
        let span: Double = max(peak - floor, 1)
        let inset: CGFloat = scale == .fromZero ? 0 : size.height * 0.05
        let drawable: CGFloat = size.height - 2 * inset
        var path = Path()
        for (offset, point) in points.enumerated() {
            let fraction = CGFloat((point.kWh - floor) / span)
            let y: CGFloat = inset + (1 - fraction) * drawable
            let location = CGPoint(x: layout.centerX(point.index), y: y)
            if offset == 0 {
                path.move(to: location)
            } else {
                path.addLine(to: location)
            }
        }
        context.stroke(path, with: .color(Palette.ink.opacity(0.45)), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
    }

    private static func drawTexture(_ bars: [ChartBar], layout: BarLayout, in context: inout GraphicsContext, size: CGSize) {
        let texture = Palette.ink.opacity(0.08)
        for bar in bars {
            guard let pct = bar.greenPct else { continue }
            let barHeight = max(2, CGFloat(pct) / 100 * size.height)
            let rect = CGRect(x: layout.minX(bar.index), y: size.height - barHeight, width: layout.barWidth + 0.6, height: barHeight)
            context.fill(Path(rect), with: .color(texture))
        }
    }

    private static func drawMonths(_ months: [MonthSummary], focusMonthStart: Int?, layout: BarLayout, in context: inout GraphicsContext, size: CGSize) {
        for month in months {
            let minX = layout.minX(month.startIndex) + 1
            let maxX = layout.minX(month.endIndex) + layout.barWidth - 1
            guard maxX > minX else { continue }
            guard let average = month.average else {
                let base = CGRect(x: minX, y: size.height - 2, width: maxX - minX, height: 2)
                context.fill(Path(roundedRect: base, cornerRadius: 1), with: .color(Palette.emptyBar.opacity(0.6)))
                continue
            }
            let blockHeight = max(4, CGFloat(average) / 100 * size.height)
            let rect = CGRect(x: minX, y: size.height - blockHeight, width: maxX - minX, height: blockHeight)
            let shape = UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3).path(in: rect)
            let isFocus = month.startIndex == focusMonthStart
            context.fill(shape, with: .color(GreenBand(percentage: average).color.opacity(isFocus ? 1 : 0.8)))
        }
    }
}

struct ChartMarkers: View {
    let layout: BarLayout
    let currentIndex: Int?
    let focusIndex: Int?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let currentIndex {
                Rectangle()
                    .fill(Palette.ink.opacity(0.35))
                    .frame(width: 1, height: ChartMetrics.plotHeight)
                    .offset(x: layout.centerX(currentIndex) - 0.5)
            }
            if let focusIndex {
                FocusIndicator()
                    .frame(height: ChartMetrics.plotHeight + 14)
                    .offset(x: layout.centerX(focusIndex) - FocusIndicator.width / 2, y: -10)
                    .animation(.easeOut(duration: 0.15), value: focusIndex)
            }
        }
    }
}

struct AxisMark: Identifiable {
    let index: Int
    let text: String

    var id: Int { index }
}

struct AxisMarks: View {
    let layout: BarLayout
    let marks: [AxisMark]
    let currentIndex: Int?

    private var currentX: CGFloat? { currentIndex.map { layout.centerX($0) } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(marks) { mark in
                let x = layout.centerX(mark.index)
                if currentX.map({ abs($0 - x) > 24 }) ?? true {
                    AxisLabel(text: mark.text, isEmphasized: false)
                        .position(x: clamped(x), y: ChartMetrics.axisHeight / 2 + 2)
                }
            }
            if let currentX {
                AxisLabel(text: "NU", isEmphasized: true)
                    .position(x: clamped(currentX), y: ChartMetrics.axisHeight / 2 + 2)
            }
        }
        .frame(width: layout.width, height: ChartMetrics.axisHeight)
        .accessibilityHidden(true)
    }

    private func clamped(_ x: CGFloat) -> CGFloat {
        min(max(x, 12), layout.width - 12)
    }
}

struct MonthAxis: View {
    let layout: BarLayout
    let months: [MonthSummary]
    let focusMonthStart: Int?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(months) { month in
                let isFocus = month.startIndex == focusMonthStart
                let x = (layout.minX(month.startIndex) + layout.minX(month.endIndex) + layout.barWidth) / 2
                VStack(spacing: 3) {
                    Text(verbatim: DutchFormat.monthShort(month.month))
                        .font(.system(size: 9, weight: isFocus ? .semibold : .regular))
                        .tracking(1.2)
                        .foregroundStyle(isFocus ? Palette.ink : Palette.dim2)
                    Text(verbatim: month.average.map { DutchFormat.percent($0) } ?? "–")
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(month.average.map { GreenBand(percentage: $0).labelColor } ?? Palette.dim2.opacity(0.5))
                }
                .fixedSize()
                .position(x: x, y: ChartMetrics.monthAxisHeight / 2 + 2)
            }
        }
        .frame(width: layout.width, height: ChartMetrics.monthAxisHeight)
        .accessibilityHidden(true)
    }
}

struct ChartRule: View {
    var body: some View {
        Rectangle()
            .fill(Palette.rule2)
            .frame(height: 1)
            .padding(.top, ChartMetrics.ruleSpacing)
    }
}

struct AxisLabel: View {
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

struct FocusIndicator: View {
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

extension View {
    func ignoresAccessibilityActivation() -> some View {
        accessibilityAction {}
    }
}
