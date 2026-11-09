import SwiftUI

struct HeroCard: View {
    let snapshot: Snapshot
    let nowHour: Date
    let isLoading: Bool
    let screenWidth: CGFloat

    @State private var isFlipped = false
    @AccessibilityFocusState private var focusedFace: HeroFace?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    var body: some View {
        FlipCard(isFlipped: isFlipped, reduceMotion: reduceMotion) {
            HeroFront(
                snapshot: snapshot,
                nowHour: nowHour,
                isLoading: isLoading,
                screenWidth: screenWidth,
                focus: $focusedFace,
                onInfo: { flip(to: true) }
            )
        } back: { minHeight in
            HeroBack(minHeight: minHeight, focus: $focusedFace, onClose: { flip(to: false) })
        }
        .shadow(color: .black.opacity(0.16), radius: 24, x: 0, y: 14)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
    }

    private func flip(to flipped: Bool) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.6, bounce: 0.08)) {
            isFlipped = flipped
        }
        focusedFace = flipped ? .back : .front
    }
}

private enum HeroFace: Hashable {
    case front
    case back
}

private struct HeroFront: View {
    let snapshot: Snapshot
    let nowHour: Date
    let isLoading: Bool
    let screenWidth: CGFloat
    let focus: AccessibilityFocusState<HeroFace?>.Binding
    let onInfo: () -> Void

    @ScaledMetric(relativeTo: .title2) private var captionSize: CGFloat = 24
    @ScaledMetric(relativeTo: .subheadline) private var usageSize: CGFloat = 14

    private var numberSize: CGFloat { min(max(screenWidth * 0.32, 96), 208) }
    private var percentSize: CGFloat { min(max(screenWidth * 0.07, 32), 56) }
    private var band: GreenBand { GreenBand(percentage: snapshot.greenPct) }

    private var isPreliminaryDay: Bool {
        snapshot.span == .day && snapshot.date == DutchFormat.startOfDay(nowHour)
    }

    private var title: String {
        switch snapshot.span {
        case .hour: DutchFormat.long(snapshot.date)
        case .day: DutchFormat.dayLong(snapshot.date, now: nowHour)
        }
    }

    private var relative: String {
        switch snapshot.span {
        case .hour: DutchFormat.relative(hour: snapshot.date, now: nowHour)
        case .day: DutchFormat.dayRelative(snapshot.date, now: nowHour)
        }
    }

    private var usage: String {
        let amount = DutchFormat.gigawattHours(snapshot.totalKWh)
        switch snapshot.span {
        case .hour: return "\(amount) verbruik"
        case .day: return isPreliminaryDay ? "\(amount) verbruik · voorlopig" : "\(amount) verbruik op deze dag"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MicroLabel(text: title, baseSize: 11, trackingRatio: 0.2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .padding(.trailing, 40)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(snapshot.roundedGreenPct)")
                    .font(.system(size: numberSize, weight: .semibold))
                    .tracking(-numberSize * 0.05)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(snapshot.roundedGreenPct)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(verbatim: "%")
                    .font(.system(size: percentSize, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.top, 4)
            .padding(.vertical, -numberSize * 0.1)

            Text("duurzaam \(Text(verbatim: "· \(relative)").foregroundStyle(.white.opacity(0.6)))")
                .font(.system(size: captionSize, weight: .light))
                .tracking(-0.3)
                .foregroundStyle(.white.opacity(0.95))
                .padding(.top, 4)

            if snapshot.totalKWh > 0 {
                Text(verbatim: usage)
                    .font(.system(size: usageSize, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 32)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .background(CardGradient(band: band).animation(.easeInOut(duration: 0.5), value: band))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 2) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                        .accessibilityLabel("Bezig met laden")
                }
                Button(action: onInfo) {
                    Text(verbatim: "i")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.white.opacity(0.12)))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Over deze app")
                .accessibilityFocused(focus, equals: .front)
            }
            .padding(6)
        }
    }

    private var accessibilityText: String {
        var parts = [
            "\(snapshot.roundedGreenPct) procent duurzame stroom",
            relative,
            title,
        ]
        if snapshot.totalKWh > 0 {
            parts.append(usage.replacingOccurrences(of: "GWh", with: "gigawattuur"))
        }
        return parts.joined(separator: ", ")
    }
}

private struct HeroBack: View {
    let minHeight: CGFloat?
    let focus: AccessibilityFocusState<HeroFace?>.Binding
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var bodySize: CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var smallSize: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MicroLabel(text: "Over Stroompeil", baseSize: 10, trackingRatio: 0.26)
                .foregroundStyle(.white.opacity(0.5))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused(focus, equals: .back)

            paragraph("Moet ik mijn auto nu opladen, of is de stroom straks groener? Die vraag was de aanleiding voor dit project. De bestaande apps vond ik niet mooi genoeg, dus bouwde ik dit zelf.")
            paragraph("Het grote getal is het percentage groene stroom in Nederland op dit moment. Tik op de tijdlijn of sleep eroverheen om andere uren te vergelijken.")
            paragraph("Data van ned.nl, het platform van de Nederlandse netbeheerders. De duiding wordt automatisch geschreven door een taalmodel.", opacity: 0.6)

            HStack(spacing: 16) {
                Link("Privacybeleid", destination: AppConfig.privacyURL)
                Link("Ondersteuning", destination: AppConfig.supportURL)
            }
            .font(.system(size: smallSize))
            .foregroundStyle(.white.opacity(0.75))
            .underline()

            Text("Renko Steenbeek")
                .font(.system(size: smallSize, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 28)
        .padding(.top, 32)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(CardGradient(top: Color(hex: 0x2A2926), bottom: Color(hex: 0x1A1A19)))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white.opacity(0.15)))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel("Sluiten")
        }
    }

    private func paragraph(_ text: String, opacity: Double = 0.85) -> some View {
        Text(text)
            .font(.system(size: bodySize, weight: .light))
            .lineSpacing(bodySize * 0.4)
            .foregroundStyle(.white.opacity(opacity))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct FlipCard<Front: View, Back: View>: View {
    let isFlipped: Bool
    let reduceMotion: Bool
    @ViewBuilder let front: Front
    @ViewBuilder let back: (CGFloat?) -> Back

    @State private var frontHeight: CGFloat = 0
    @State private var backHeight: CGFloat = 0

    var body: some View {
        let angle: Double = isFlipped ? 180 : 0
        ZStack(alignment: .top) {
            front
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { frontHeight = $0 }
                .modifier(FlipFace(angle: angle, isBack: false, rotates: !reduceMotion))
                .accessibilityHidden(isFlipped)
                .allowsHitTesting(!isFlipped)

            back(frontHeight > 0 ? frontHeight : nil)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { backHeight = $0 }
                .modifier(FlipFace(angle: angle, isBack: true, rotates: !reduceMotion))
                .accessibilityHidden(!isFlipped)
                .allowsHitTesting(isFlipped)
        }
        .frame(height: containerHeight, alignment: .top)
    }

    private var containerHeight: CGFloat? {
        guard frontHeight > 0 else { return nil }
        return isFlipped ? max(frontHeight, backHeight) : frontHeight
    }
}

private struct FlipFace: ViewModifier, Animatable {
    var angle: Double
    let isBack: Bool
    let rotates: Bool

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let showingBack = angle > 90
        let visible = showingBack == isBack
        content
            .opacity(rotates ? (visible ? 1 : 0) : (isBack ? angle / 180 : 1 - angle / 180))
            .rotation3DEffect(
                .degrees(rotates ? (isBack ? angle - 180 : angle) : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.45
            )
    }
}
