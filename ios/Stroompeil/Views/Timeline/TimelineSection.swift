import SwiftUI

struct TimelineSection: View {
    let model: DashboardModel

    @State private var scrubHour: Date?
    @State private var scrubDay: Date?
    @State private var zoomDirection: ZoomDirection = .zoomingOut
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var previewSize: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 16 - ChartMetrics.touchSlop)
            ZStack(alignment: .topLeading) {
                if model.scale == .day {
                    HourChart(model: model, scrubHour: $scrubHour, onZoom: requestZoom)
                        .transition(zoomDirection.transition(anchor: model.window.fraction(of: model.focusHour), reduceMotion: reduceMotion))
                } else {
                    PeriodChart(model: model, scrubDay: $scrubDay, onZoom: requestZoom)
                        .transition(zoomDirection.transition(anchor: model.periodWindow.fraction(of: model.focusDay), reduceMotion: reduceMotion))
                        .id(model.scale)
                }
            }
            .frame(height: ChartMetrics.height(axis: model.scale == .year ? ChartMetrics.monthAxisHeight : ChartMetrics.axisHeight))
            .mask(Rectangle().padding(.vertical, -6))
            footer
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.scale)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScaleSelector(selected: model.scale) { requestZoom(to: $0, at: nil) }
            preview
                .font(.system(size: previewSize))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 132)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottomLeading)
        .overlay(alignment: .bottomTrailing) { controls }
    }

    private var controls: some View {
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

    @ViewBuilder
    private var footer: some View {
        if model.scale == .day {
            if model.hourly.failed {
                retryLine("Het dagritme kon niet worden geladen.", action: { model.hourly.loadRecent(reload: true) })
            }
        } else if model.history.failedYears.contains(DutchFormat.year(model.focusDay)), model.periodDays.isEmpty {
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

    @ViewBuilder
    private var preview: some View {
        if model.scale == .day {
            let hour = scrubHour ?? model.focusHour
            let point = model.hourly.points[hour]
            PreviewLine(
                title: DutchFormat.compact(hour),
                greenPct: point?.greenPct,
                totalKWh: point?.totalKWh,
                badge: hour > model.nowHour ? "VERWACHTING" : nil
            )
        } else {
            let day = scrubDay ?? model.focusDay
            let point = model.history.days[day]
            PreviewLine(
                title: DutchFormat.dayCompact(day, now: model.nowHour),
                greenPct: point?.greenPct,
                totalKWh: point?.totalKWh,
                badge: day == model.today && point != nil ? "VOORLOPIG" : nil
            )
        }
    }

    private func requestZoom(to scale: TimeScale, at day: Date?) {
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
}

private struct PreviewLine: View {
    let title: String
    let greenPct: Double?
    let totalKWh: Double?
    let badge: String?

    var body: some View {
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
}
