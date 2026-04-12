import SwiftUI
import WidgetKit

struct EnergiemixWidget: Widget {
    let kind = "EnergiemixWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EnergiemixProvider()) { entry in
            EnergiemixWidgetView(entry: entry)
        }
        .configurationDisplayName("Stroompeil")
        .description("Hoe groen is de Nederlandse stroom nu?")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct EnergiemixWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: EnergyEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: EnergyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(entry.greenPct)")
                    .font(.system(size: 56, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("%")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text("duurzaam")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(.white.opacity(0.95))
            Text(entry.totalGWh + " verbruik")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            energyGradient(for: entry.greenPct)
        }
    }
}

struct MediumWidgetView: View {
    let entry: EnergyEntry

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(entry.greenPct)")
                        .font(.system(size: 56, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("%")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text("duurzaam")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(.white.opacity(0.95))
                Text(entry.totalGWh + " verbruik")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Spacer()
                ForEach(Array(entry.topSources.enumerated()), id: \.offset) { _, source in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(source.color)
                            .frame(width: 8, height: 8)
                        Text(source.label)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text("\(source.pct)%")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) {
            energyGradient(for: entry.greenPct)
        }
    }
}

private func energyGradient(for pct: Int) -> some View {
    RadialGradient(
        colors: [
            colorForGreenPct(pct),
            colorForGreenPctSoft(pct),
            Color(hex: "#0a0a0a")
        ],
        center: UnitPoint(x: 0.28, y: 0),
        startRadius: 0,
        endRadius: 300
    )
}
