import SwiftUI

struct SectionLabel: View {
    let text: String
    let bottomPadding: CGFloat

    init(_ text: String, bottomPadding: CGFloat = 20) {
        self.text = text
        self.bottomPadding = bottomPadding
    }

    var body: some View {
        MicroLabel(text: text, baseSize: 10, trackingRatio: 0.26)
            .foregroundStyle(Palette.dim)
            .padding(.bottom, bottomPadding)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .accessibilityAddTraits(.isHeader)
    }
}

struct MicroLabel: View {
    let text: String
    let baseSize: CGFloat
    let trackingRatio: CGFloat
    @ScaledMetric private var scale: CGFloat = 1

    init(text: String, baseSize: CGFloat, trackingRatio: CGFloat) {
        self.text = text
        self.baseSize = baseSize
        self.trackingRatio = trackingRatio
        _scale = ScaledMetric(wrappedValue: 1, relativeTo: .caption2)
    }

    var body: some View {
        let size = baseSize * scale
        Text(verbatim: text.uppercased())
            .font(.system(size: size, weight: .regular))
            .tracking(size * trackingRatio)
    }
}

struct SkeletonLines: View {
    let widths: [CGFloat]
    var height: CGFloat = 12
    var spacing: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, fraction in
                GeometryReader { proxy in
                    Capsule()
                        .fill(Palette.rule2)
                        .frame(width: proxy.size.width * fraction)
                }
                .frame(height: height)
            }
        }
    }
}

struct Pulsing: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.45 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
    }
}

struct LoadingSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Palette.rule2)
                .frame(height: 280)
            SkeletonLines(widths: [0.7, 1, 0.45])
                .padding(.top, 56)
        }
        .modifier(Pulsing())
        .accessibilityElement()
        .accessibilityLabel("Gegevens worden geladen")
    }
}

struct StatusCard: View {
    let title: String
    let message: String
    let retry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.medium))
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Palette.dim)
                .fixedSize(horizontal: false, vertical: true)
            if let retry {
                Button(action: retry) {
                    Text("Opnieuw proberen")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .overlay(Capsule().stroke(Palette.rule, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .bottomLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Palette.chip)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Palette.rule, lineWidth: 1)
        )
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for item in row.items {
                let origin = CGPoint(x: x, y: y + (row.height - item.size.height) / 2)
                subviews[item.index].place(at: origin, proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for (index, subview) in subviews.enumerated() {
            let size = fittedSize(of: subview, maxWidth: maxWidth)
            let proposedWidth = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if !current.items.isEmpty, proposedWidth > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append((index, size))
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }

    private func fittedSize(of subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        guard ideal.width > maxWidth else { return ideal }
        return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
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
