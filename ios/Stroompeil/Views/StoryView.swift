import SwiftUI

struct StoryView: View {
    let text: String
    let phase: StoryPhase
    let onRetry: () -> Void

    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = 18

    var body: some View {
        Group {
            if !text.isEmpty {
                storyText
            } else if phase == .loading || phase == .streaming {
                SkeletonLines(widths: [0.86, 0.72, 0.54])
                    .padding(.top, 4)
                    .modifier(Pulsing())
                    .accessibilityElement()
                    .accessibilityLabel("Duiding wordt geschreven")
            } else if phase == .unavailable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("De duiding is nu niet beschikbaar.")
                        .font(.system(size: size * 0.85, weight: .light))
                        .foregroundStyle(Palette.dim)
                    Button("Opnieuw proberen", action: onRetry)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
    }

    private var storyText: some View {
        let body = Text(verbatim: text)
        let caret = Text(verbatim: phase == .streaming ? " ▍" : "").foregroundStyle(Palette.dim2)
        return Text("\(body)\(caret)")
            .font(.system(size: size, weight: .light))
            .lineSpacing(size * 0.32)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text(verbatim: text))
    }
}
