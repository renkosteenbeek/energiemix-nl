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

struct PeriodBar: Identifiable {
    let index: Int
    let day: Date
    let greenPct: Double?
    let totalKWh: Double?
    let isToday: Bool
    let isFuture: Bool

    var id: Int { index }
}

enum ZoomDirection {
    case zoomingOut
    case zoomingIn
}

struct RhythmView: View {
    let model: DashboardModel

    @State private var scrubHour: Date?
    @State private var scrubDay: Date?
    @State private var tapCount = 0
    @State private var zoomDirection: ZoomDirection = .zoomingOut
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var previewSize: CGFloat = 13

    private let chartHeight: CGFloat = 96
    private let axisHeight: CGFloat = 22
    private let yearAxisHeight: CGFloat = 36
    private let touchSlop: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 16 - touchSlop)
            ZStack(alignment: .topLeading) {
                if model.scale == .day {
                    hourChart
                } else {
                    periodChart
                        .id(model.scale)
                }
            }
            .frame(height: touchSlop + chartHeight + 9 + (model.scale == .year ? yearAxisHeight : axisHeight))
            .mask(Rectangle().padding(.vertical, -6))
            footer
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.scale)
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ScaleSelector(selected: model.scale) { requestZoom(to: $0) }
                previewLine
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

                CircleControl(enabled: model.canPanBack, accessibilityLabel: "\(model.scale.title) eerder", action: model.panBack) {
                    Image(systemName: "chevron.left.2")
                        .font(.system(size: 11, weight: .semibold))
                }
                CircleControl(enabled: model.canPanForward, accessibilityLabel: "\(model.scale.title) later", action: model.panForward) {
                    Image(systemName: "chevron.right.2")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if model.scale == .day {
            if model.timelineFailed {
                retryLine("Het dagritme kon niet worden geladen.", action: model.retryTimeline)
            }
        } else if model.failedYears.contains(DutchFormat.year(model.focusDay)), model.periodDays.isEmpty {
            retryLine("De gegevens van deze periode konden niet worden geladen.", action: model.retry)
        } else if let stats = model.periodStats {
            PeriodSummary(stats: stats, now: model.nowHour, onSelect: model.selectDay)
                .padding(.top, 6)
        }
    }

    private func retryLine(_ message: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text(message)
                .foregroundStyle(Palette.dim)
            Button("Opnieuw", action: action)
                .fontWeight(.medium)
                .foregroundStyle(Palette.ink)
        }
        .font(.footnote)
        .padding(.top, 4)
    }

    private func requestZoom(to scale: TimeScale, at day: Date? = nil) {
        guard scale != model.scale else { return }
        zoomDirection = scale > model.scale ? .zoomingOut : .zoomingIn
        let animation: Animation = reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.5)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            withAnimation(animation) {
                if let day { model.selectDay(day) }
                model.zoom(to: scale)
            }
        }
    }

    private func handlePinch(zoomIn: Bool, day: Date?) {
        if zoomIn {
            if let finer = model.scale.finer { requestZoom(to: finer, at: day) }
        } else if let coarser = model.scale.coarser {
            requestZoom(to: coarser)
        }
    }

    private func zoomTransition(anchor: CGFloat) -> AnyTransition {
        if reduceMotion { return .opacity }
        let enlarged: CGFloat = 4
        let reduced: CGFloat = 0.25
        let insertionScale = zoomDirection == .zoomingOut ? enlarged : reduced
        let removalScale = zoomDirection == .zoomingOut ? reduced : enlarged
        return .asymmetric(
            insertion: .modifier(
                active: ZoomEffect(scaleX: insertionScale, anchorX: anchor, opacity: 0),
                identity: ZoomEffect(scaleX: 1, anchorX: anchor, opacity: 1)
            ),
            removal: .modifier(
                active: ZoomEffect(scaleX: removalScale, anchorX: anchor, opacity: 0),
                identity: ZoomEffect(scaleX: 1, anchorX: anchor, opacity: 1)
            )
        )
    }

    @ViewBuilder
    private var previewLine: some View {
        if model.scale == .day {
            hourPreview(hour: scrubHour ?? model.focusHour)
        } else {
            dayPreview(day: scrubDay ?? model.focusDay)
        }
    }

    private func hourPreview(hour: Date) -> Text {
        let point = model.timelineByHour[hour]
        return preview(
            title: DutchFormat.compact(hour),
            greenPct: point?.greenPct,
            totalKWh: point?.totalKWh,
            badge: hour > model.nowHour ? "FORECAST" : nil
        )
    }

    private func dayPreview(day: Date) -> Text {
        let point = model.daysByDate[day]
        return preview(
            title: DutchFormat.dayCompact(day, now: model.nowHour),
            greenPct: point?.greenPct,
            totalKWh: point?.totalKWh,
            badge: day == model.today && point != nil ? "VOORLOPIG" : nil
        )
    }

    private func preview(title: String, greenPct: Double?, totalKWh: Double?, badge: String?) -> Text {
        let separator = Text(verbatim: " · ").foregroundStyle(Palette.dim2)
        var line = Text(verbatim: title).foregroundStyle(Palette.ink)
        if let greenPct {
            let pct = Text(verbatim: DutchFormat.percent(greenPct))
                .fontWeight(.medium)
                .foregroundStyle(GreenBand(percentage: greenPct).labelColor)
            line = Text("\(line)\(separator)\(pct)")
        }
        if let totalKWh, totalKWh > 0 {
            let usage = Text(verbatim: DutchFormat.gigawattHours(totalKWh)).foregroundStyle(Palette.dim)
            line = Text("\(line)\(separator)\(usage)")
        }
        if let badge {
            let label = Text(verbatim: "  \(badge)")
                .font(.system(size: 9))
                .tracking(1.6)
                .foregroundStyle(Palette.dim2)
            line = Text("\(line)\(label)")
        }
        return line.monospacedDigit()
    }

    private var hourChart: some View {
        let window = model.window
        let bars = (0..<window.count).map { index in
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
        let effectiveHour = scrubHour ?? model.focusHour
        let focusIndex = window.index(of: effectiveHour)
        let anchor = focusIndex.map { (CGFloat($0) + 0.5) / CGFloat(window.count) } ?? 0.5

        return GeometryReader { proxy in
            let layout = BarLayout(width: proxy.size.width, count: bars.count)
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: touchSlop)
                RhythmPlot(bars: bars, layout: layout, focusIndex: focusIndex, nowIndex: window.nowIndex, height: chartHeight)

                Rectangle()
                    .fill(Palette.rule2)
                    .frame(height: 1)
                    .padding(.top, 8)

                RhythmAxis(bars: bars, layout: layout, nowIndex: window.nowIndex, height: axisHeight)
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
                    onPinch: { zoomIn, _ in handlePinch(zoomIn: zoomIn, day: nil) }
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
        .accessibilityAction {}
        .accessibilityAction(named: "Uitzoomen") { requestZoom(to: .month) }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.step(by: 1)
            case .decrement: model.step(by: -1)
            @unknown default: break
            }
        }
        .transition(zoomTransition(anchor: anchor))
    }

    private var periodChart: some View {
        let window = model.periodWindow
        let today = model.today
        let bars = (0..<window.count).map { index in
            let day = window.day(at: index)
            let point = model.daysByDate[day]
            return PeriodBar(
                index: index,
                day: day,
                greenPct: point?.greenPct,
                totalKWh: point?.totalKWh,
                isToday: day == today,
                isFuture: day > today
            )
        }
        let effectiveDay = scrubDay ?? model.focusDay
        let focusIndex = window.index(of: effectiveDay)
        let todayIndex = window.index(of: today)
        let anchor = focusIndex.map { (CGFloat($0) + 0.5) / CGFloat(window.count) } ?? 0.5
        let isYear = window.isYear
        let months = isYear ? window.monthSummaries(days: model.daysByDate) : []
        let focusMonth = focusIndex.flatMap { index in months.first { $0.contains(index) } }

        return GeometryReader { proxy in
            let layout = BarLayout(width: proxy.size.width, count: bars.count, gap: isYear ? 0 : 2)
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: touchSlop)
                PeriodPlot(
                    bars: bars,
                    months: months,
                    focusMonthStart: focusMonth?.startIndex,
                    layout: layout,
                    focusIndex: focusIndex,
                    todayIndex: todayIndex,
                    height: chartHeight
                )

                Rectangle()
                    .fill(Palette.rule2)
                    .frame(height: 1)
                    .padding(.top, 8)

                PeriodAxis(
                    bars: bars,
                    months: months,
                    focusMonthStart: focusMonth?.startIndex,
                    layout: layout,
                    todayIndex: todayIndex,
                    height: isYear ? yearAxisHeight : axisHeight
                )
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
                        handlePinch(zoomIn: zoomIn, day: min(window.day(at: layout.index(at: x)), today))
                    }
                )
            }
        }
        .sensoryFeedback(trigger: scrubDay) { old, new in
            guard let new else { return nil }
            guard let old else { return .impact(weight: .medium) }
            if isYear {
                return DutchFormat.calendar.isDate(old, equalTo: new, toGranularity: .month) ? nil : .selection
            }
            return old == new ? nil : .selection
        }
        .sensoryFeedback(.selection, trigger: tapCount)
        .accessibilityElement()
        .accessibilityLabel(isYear ? "Tijdlijn per dag over \(window.title)" : "Tijdlijn per dag in \(window.title)")
        .accessibilityValue(spokenDayValue(for: model.focusDay, months: months, window: window))
        .accessibilityHint("Veeg omhoog of omlaag om een andere dag te kiezen.")
        .accessibilityAction {}
        .accessibilityAction(named: "Inzoomen") { requestZoom(to: isYear ? .month : .day) }
        .accessibilityAction(named: "Uitzoomen") { if !isYear { requestZoom(to: .year) } }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.step(by: 1)
            case .decrement: model.step(by: -1)
            @unknown default: break
            }
        }
        .transition(zoomTransition(anchor: anchor))
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

    private func spokenDayValue(for day: Date, months: [MonthSummary], window: PeriodWindow) -> String {
        var parts = [DutchFormat.dayLong(day, now: model.nowHour)]
        if let point = model.daysByDate[day] {
            parts.append("\(Int(point.greenPct.rounded())) procent duurzaam")
            parts.append("\(DutchFormat.gigawattHoursSpoken(point.totalKWh)) verbruik")
            if day == model.today { parts.append("voorlopig") }
        } else {
            parts.append("geen gegevens")
        }
        if let index = window.index(of: day),
           let month = months.first(where: { $0.contains(index) }),
           let average = month.average {
            parts.append("\(DutchFormat.monthTitle(month.month)) gemiddeld \(Int(average.rounded())) procent")
        }
        return parts.joined(separator: ", ")
    }
}

private struct ZoomEffect: ViewModifier {
    let scaleX: CGFloat
    let anchorX: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: scaleX, y: 1, anchor: UnitPoint(x: anchorX, y: 1))
            .opacity(opacity)
    }
}

private struct ScaleSelector: View {
    let selected: TimeScale
    let onSelect: (TimeScale) -> Void

    @Namespace private var underline

    var body: some View {
        HStack(spacing: 16) {
            ForEach(TimeScale.allCases, id: \.self) { scale in
                let isSelected = scale == selected
                Button {
                    onSelect(scale)
                } label: {
                    MicroLabel(text: scale.title, baseSize: 10, trackingRatio: 0.26)
                        .foregroundStyle(isSelected ? Palette.ink : Palette.dim2)
                        .overlay(alignment: .bottom) {
                            if isSelected {
                                Capsule()
                                    .fill(Palette.ink)
                                    .frame(height: 1.5)
                                    .offset(y: 5)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(scale.title)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, -10)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .animation(.snappy(duration: 0.3), value: selected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tijdschaal")
    }
}

private struct PeriodSummary: View {
    let stats: PeriodStats
    let now: Date
    let onSelect: (Date) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            Text("Gemiddeld \(Text(verbatim: DutchFormat.percent(stats.average)).foregroundStyle(Palette.ink).fontWeight(.medium))")
                .foregroundStyle(Palette.dim)
            separator
            dayLink(prefix: "groenst", point: stats.greenest)
            separator
            dayLink(prefix: "grijst", point: stats.greyest)
        }
        .font(.footnote)
        .monospacedDigit()
    }

    private var separator: some View {
        Text(verbatim: "·")
            .foregroundStyle(Palette.dim2)
            .accessibilityHidden(true)
    }

    private func dayLink(prefix: String, point: DayPoint) -> some View {
        Button {
            onSelect(point.day)
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(GreenBand(percentage: point.greenPct).color)
                    .frame(width: 6, height: 6)
                Text("\(Text(verbatim: prefix).foregroundStyle(Palette.dim)) \(Text(verbatim: DutchFormat.dayShort(point.day, now: now)).foregroundStyle(Palette.ink).fontWeight(.medium))")
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(prefix == "groenst" ? "Groenste" : "Grijste") dag: \(DutchFormat.dayLong(point.day, now: now)), \(Int(point.greenPct.rounded())) procent")
        .accessibilityHint("Toont deze dag.")
    }
}

private struct PeriodPlot: View {
    let bars: [PeriodBar]
    let months: [MonthSummary]
    let focusMonthStart: Int?
    let layout: BarLayout
    let focusIndex: Int?
    let todayIndex: Int?
    let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            canvas
            if let todayIndex {
                Rectangle()
                    .fill(Palette.ink.opacity(0.35))
                    .frame(width: 1, height: height)
                    .offset(x: layout.centerX(todayIndex) - 0.5)
            }
            if let focusIndex {
                FocusIndicator()
                    .frame(height: height + 14)
                    .offset(x: layout.centerX(focusIndex) - FocusIndicator.width / 2, y: -10)
                    .animation(.easeOut(duration: 0.15), value: focusIndex)
            }
        }
        .frame(width: layout.width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var canvas: some View {
        let bars = bars
        let months = months
        let focusMonthStart = focusMonthStart
        let layout = layout
        return Canvas { context, size in
            if !months.isEmpty {
                Self.drawMonths(months, bars: bars, focusMonthStart: focusMonthStart, layout: layout, in: &context, size: size)
                return
            }
            let overlap: CGFloat = layout.gap == 0 ? 0.6 : 0
            for bar in bars {
                let barHeight: CGFloat
                let color: Color
                if let pct = bar.greenPct {
                    barHeight = max(4, CGFloat(pct) / 100 * size.height)
                    color = GreenBand(percentage: pct).color.opacity(bar.isToday ? 0.7 : 1)
                } else {
                    barHeight = bar.isFuture ? 2 : 4
                    color = Palette.emptyBar.opacity(bar.isFuture ? 0.6 : 1)
                }
                let rect = CGRect(
                    x: layout.minX(bar.index),
                    y: size.height - barHeight,
                    width: layout.barWidth + overlap,
                    height: barHeight
                )
                context.fill(Path(roundedRect: rect, cornerRadius: layout.gap == 0 ? 0 : 1), with: .color(color))
            }

            var measured: [(index: Int, kWh: Double)] = []
            for bar in bars {
                if let kWh = bar.totalKWh, kWh > 0, !bar.isToday {
                    measured.append((bar.index, kWh))
                }
            }
            let points = measured
            guard points.count >= 2, let peak = points.map(\.kWh).max(), peak > 0 else { return }
            let floor = (points.map(\.kWh).min() ?? 0) * 0.85
            let span = max(peak - floor, 1)
            var path = Path()
            for (offset, point) in points.enumerated() {
                let location = CGPoint(
                    x: layout.centerX(point.index),
                    y: (1 - CGFloat((point.kWh - floor) / span)) * size.height * 0.9 + size.height * 0.05
                )
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
        .frame(width: layout.width, height: height)
        .id(colorScheme)
    }

    private static func drawMonths(
        _ months: [MonthSummary],
        bars: [PeriodBar],
        focusMonthStart: Int?,
        layout: BarLayout,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let texture = Palette.ink.opacity(0.08)
        for bar in bars {
            guard let pct = bar.greenPct else { continue }
            let barHeight = max(2, CGFloat(pct) / 100 * size.height)
            let rect = CGRect(x: layout.minX(bar.index), y: size.height - barHeight, width: layout.barWidth + 0.6, height: barHeight)
            context.fill(Path(rect), with: .color(texture))
        }

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

private struct PeriodAxis: View {
    let bars: [PeriodBar]
    let months: [MonthSummary]
    let focusMonthStart: Int?
    let layout: BarLayout
    let todayIndex: Int?
    let height: CGFloat

    private var todayX: CGFloat? { todayIndex.map { layout.centerX($0) } }

    private var marks: [(id: Int, x: CGFloat, text: String)] {
        let calendar = DutchFormat.calendar
        return bars.compactMap { bar in
            guard calendar.component(.weekday, from: bar.day) == 2 else { return nil }
            return (bar.index, layout.centerX(bar.index), String(calendar.component(.day, from: bar.day)))
        }
    }

    var body: some View {
        if months.isEmpty {
            dayMarks
        } else {
            monthMarks
        }
    }

    private var monthMarks: some View {
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
                .position(x: x, y: height / 2 + 2)
            }
        }
        .frame(width: layout.width, height: height)
        .accessibilityHidden(true)
    }

    private var dayMarks: some View {
        ZStack(alignment: .topLeading) {
            ForEach(marks, id: \.id) { mark in
                if todayX.map({ abs($0 - mark.x) > 22 }) ?? true {
                    AxisLabel(text: mark.text, isEmphasized: false)
                        .position(x: clamped(mark.x), y: height / 2 + 2)
                }
            }
            if let todayX {
                AxisLabel(text: "NU", isEmphasized: true)
                    .position(x: clamped(todayX), y: height / 2 + 2)
            }
        }
        .frame(width: layout.width, height: height)
        .accessibilityHidden(true)
    }

    private func clamped(_ x: CGFloat) -> CGFloat {
        min(max(x, 12), layout.width - 12)
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
        return max(0, layout.minX(index) - layout.gap / 2)
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
    let onPinch: (Bool, CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = context.coordinator
        context.coordinator.pan = pan
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pinch)
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
        weak var pan: UIPanGestureRecognizer?
        private var pinchHandled = false

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

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                pinchHandled = false
                if let pan, pan.state == .began || pan.state == .changed {
                    pan.isEnabled = false
                    pan.isEnabled = true
                }
            case .changed:
                guard !pinchHandled else { return }
                let x = recognizer.location(in: recognizer.view).x
                if recognizer.scale < 0.7 {
                    pinchHandled = true
                    surface.onPinch(false, x)
                } else if recognizer.scale > 1.4 {
                    pinchHandled = true
                    surface.onPinch(true, x)
                }
            default:
                pinchHandled = false
            }
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return pan.numberOfTouches == 1 && abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            (recognizer is UIPinchGestureRecognizer && other === pan) || (recognizer === pan && other is UIPinchGestureRecognizer)
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
