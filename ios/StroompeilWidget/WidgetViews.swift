import SwiftUI
import WidgetKit

struct StroompeilWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EnergyEntry

    var body: some View {
        content
            .environment(\.colorScheme, family.isAccessory ? colorScheme : .dark)
            .widgetURL(AppConfig.nowDeepLink)
    }

    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    private var content: some View {
        switch entry.content {
        case .mix(let mix):
            switch family {
            case .systemMedium: MediumWidgetView(mix: mix)
            case .accessoryCircular: CircularWidgetView(mix: mix)
            case .accessoryRectangular: RectangularWidgetView(mix: mix)
            case .accessoryInline: InlineWidgetView(mix: mix)
            default: SmallWidgetView(mix: mix)
            }
        case .unavailable:
            UnavailableWidgetView(family: family)
        }
    }
}

private extension WidgetFamily {
    var isAccessory: Bool {
        switch self {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: true
        default: false
        }
    }
}

private struct HeadlineBlock: View {
    let mix: Mix

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: DutchFormat.clock(mix.focusTime))
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: "\(mix.roundedGreenPct)")
                    .font(.system(size: 56, weight: .semibold))
                    .tracking(-2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                Text(verbatim: "%")
                    .font(.system(size: 24, weight: .light))
                    .opacity(0.85)
            }
            Text("duurzaam")
                .font(.system(size: 17, weight: .light))
                .opacity(0.95)
            if mix.totalKWh > 0 {
                Text(verbatim: "\(DutchFormat.gigawattHours(mix.totalKWh)) verbruik")
                    .font(.system(size: 12, weight: .light))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .opacity(0.5)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = "\(mix.roundedGreenPct) procent duurzame stroom om \(DutchFormat.clock(mix.focusTime))"
        if mix.totalKWh > 0 {
            text += ", \(DutchFormat.gigawattHoursSpoken(mix.totalKWh)) verbruik"
        }
        return text
    }
}

private struct SmallWidgetView: View {
    let mix: Mix

    var body: some View {
        HeadlineBlock(mix: mix)
            .containerBackground(for: .widget) {
                CardGradient(band: GreenBand(percentage: mix.greenPct))
            }
    }
}

private struct MediumWidgetView: View {
    let mix: Mix

    var body: some View {
        HStack(spacing: 16) {
            HeadlineBlock(mix: mix)
            VStack(alignment: .leading, spacing: 10) {
                Spacer(minLength: 0)
                ForEach(mix.sources.prefix(3)) { source in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(source.color)
                            .frame(width: 8, height: 8)
                        Text(verbatim: source.label)
                            .font(.system(size: 13))
                            .opacity(0.85)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(verbatim: DutchFormat.percent(source.percentage))
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(source.label), \(Int(source.percentage.rounded())) procent")
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) {
            CardGradient(band: GreenBand(percentage: mix.greenPct))
        }
    }
}

private struct CircularWidgetView: View {
    let mix: Mix

    var body: some View {
        Gauge(value: min(max(mix.greenPct, 0), 100), in: 0...100) {
            Text("Groen")
        } currentValueLabel: {
            Text(verbatim: "\(mix.roundedGreenPct)")
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel("\(mix.roundedGreenPct) procent duurzame stroom")
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct RectangularWidgetView: View {
    let mix: Mix

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: "\(mix.roundedGreenPct)% duurzaam")
                .font(.headline)
                .monospacedDigit()
                .widgetAccentable()
            Text(verbatim: mix.sources.prefix(2).map { "\($0.label) \(DutchFormat.percent($0.percentage))" }.joined(separator: " · "))
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: "Stroompeil · \(DutchFormat.clock(mix.focusTime))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

private struct InlineWidgetView: View {
    let mix: Mix

    var body: some View {
        Text(verbatim: "\(mix.roundedGreenPct)% groene stroom")
            .containerBackground(for: .widget) { Color.clear }
    }
}

private struct UnavailableWidgetView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Stroompeil: geen data")
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryCircular:
            Gauge(value: 0, in: 0...100) {
                Text("Groen")
            } currentValueLabel: {
                Text(verbatim: "–")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel("Geen data")
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Geen data")
                    .font(.headline)
                Text("Stroompeil probeert het zo opnieuw.")
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { Color.clear }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Spacer(minLength: 0)
                Text("Geen data")
                    .font(.system(size: 17, weight: .medium))
                Text("Stroompeil probeert het zo opnieuw.")
                    .font(.system(size: 12, weight: .light))
                    .opacity(0.6)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) {
                CardGradient(top: Color(hex: 0x2A2926), bottom: Color(hex: 0x1A1A19))
            }
        }
    }
}
