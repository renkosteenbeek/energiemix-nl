import SwiftUI

enum ZoomDirection {
    case zoomingOut
    case zoomingIn

    func transition(anchor: CGFloat, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        let enlarged: CGFloat = 4
        let reduced: CGFloat = 0.25
        let insertion = self == .zoomingOut ? enlarged : reduced
        let removal = self == .zoomingOut ? reduced : enlarged
        return .asymmetric(
            insertion: .modifier(
                active: ZoomEffect(scaleX: insertion, anchorX: anchor, opacity: 0),
                identity: ZoomEffect(scaleX: 1, anchorX: anchor, opacity: 1)
            ),
            removal: .modifier(
                active: ZoomEffect(scaleX: removal, anchorX: anchor, opacity: 0),
                identity: ZoomEffect(scaleX: 1, anchorX: anchor, opacity: 1)
            )
        )
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

struct ScaleSelector: View {
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
                        .lineLimit(1)
                        .fixedSize()
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
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(.snappy(duration: 0.3), value: selected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tijdschaal")
    }
}

struct PeriodSummary: View {
    let stats: PeriodStats
    let now: Date
    let onSelect: (Date) -> Void

    private enum Extreme {
        case greenest
        case greyest

        var shortLabel: String { self == .greenest ? "groenst" : "grijst" }
        var spokenLabel: String { self == .greenest ? "Groenste dag" : "Grijste dag" }
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            Text("Gemiddeld \(Text(verbatim: DutchFormat.percent(stats.average)).foregroundStyle(Palette.ink).fontWeight(.medium))")
                .foregroundStyle(Palette.dim)
            separator
            link(.greenest, point: stats.greenest)
            separator
            link(.greyest, point: stats.greyest)
        }
        .font(.footnote)
        .monospacedDigit()
    }

    private var separator: some View {
        Text(verbatim: "·")
            .foregroundStyle(Palette.dim2)
            .accessibilityHidden(true)
    }

    private func link(_ extreme: Extreme, point: DayPoint) -> some View {
        Button {
            onSelect(point.day)
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(GreenBand(percentage: point.greenPct).color)
                    .frame(width: 6, height: 6)
                Text("\(Text(verbatim: extreme.shortLabel).foregroundStyle(Palette.dim)) \(Text(verbatim: DutchFormat.dayShort(point.day, now: now)).foregroundStyle(Palette.ink).fontWeight(.medium))")
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(extreme.spokenLabel): \(DutchFormat.dayLong(point.day, now: now)), \(DutchFormat.percentSpoken(point.greenPct))")
        .accessibilityHint("Toont deze dag.")
    }
}
