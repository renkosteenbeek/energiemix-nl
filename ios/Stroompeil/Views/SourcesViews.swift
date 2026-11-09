import SwiftUI

struct TopSourcesView: View {
    let sources: [SourceSlice]

    @ScaledMetric(relativeTo: .footnote) private var size: CGFloat = 13

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(sources) { source in
                HStack(spacing: 8) {
                    Circle()
                        .fill(source.color)
                        .frame(width: 6, height: 6)
                    Text(verbatim: source.label)
                        .font(.system(size: size, weight: .medium))
                    Text(verbatim: DutchFormat.percent(source.percentage))
                        .font(.system(size: size, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Palette.chip))
                .overlay(Capsule().stroke(Palette.rule, lineWidth: 1))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(source.label), \(DutchFormat.percentSpoken(source.percentage))")
            }
        }
    }
}

struct AllSourcesView: View {
    let sources: [SourceSlice]

    @SceneStorage("alleBronnenOpen") private var isOpen = false
    @State private var selectedId: Int?
    @ScaledMetric(relativeTo: .body) private var rowSize: CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var detailSize: CGFloat = 13

    private var total: Double { sources.reduce(0) { $0 + $1.volumeKWh } }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.3)) { isOpen.toggle() }
            } label: {
                HStack {
                    SectionLabel("Alle bronnen", bottomPadding: 0)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.dim2)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Alle bronnen")
            .accessibilityValue(isOpen ? "Uitgeklapt" : "Ingeklapt")
            .accessibilityAddTraits(.isButton)

            if isOpen, total > 0 {
                VStack(spacing: 24) {
                    DonutView(sources: sources, total: total, selectedId: selectedId, onSelect: toggle)
                    VStack(spacing: 2) {
                        ForEach(sources) { row(for: $0) }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Palette.rule).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.rule).frame(height: 1) }
        .onChange(of: sources.map(\.typeId)) { _, ids in
            if let selectedId, !ids.contains(selectedId) { self.selectedId = nil }
        }
    }

    private func toggle(_ id: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedId = selectedId == id ? nil : id
        }
    }

    private func row(for source: SourceSlice) -> some View {
        let isSelected = selectedId == source.typeId
        let isDimmed = selectedId != nil && !isSelected
        return Button { toggle(source.typeId) } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(source.color)
                    .frame(width: 10, height: 10)
                Text(verbatim: source.label)
                    .font(.system(size: rowSize, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: DutchFormat.megawattHours(source.volumeKWh))
                    .font(.system(size: detailSize))
                    .monospacedDigit()
                    .foregroundStyle(Palette.dim2)
                Text(verbatim: DutchFormat.percent(source.percentage))
                    .font(.system(size: rowSize, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: 52, alignment: .trailing)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isDimmed ? 0.4 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(source.label), \(DutchFormat.percentSpoken(source.percentage)), \(DutchFormat.megawattHoursSpoken(source.volumeKWh))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct DonutView: View {
    let sources: [SourceSlice]
    let total: Double
    let selectedId: Int?
    let onSelect: (Int) -> Void

    private let size: CGFloat = 200
    private let stroke: CGFloat = 28

    private struct Segment: Identifiable {
        let source: SourceSlice
        let start: Double
        let end: Double
        var id: Int { source.typeId }
    }

    private var segments: [Segment] {
        var cursor = 0.0
        return sources.map { source in
            let fraction = total > 0 ? source.volumeKWh / total : 0
            defer { cursor += fraction }
            return Segment(source: source, start: cursor, end: min(1, cursor + fraction))
        }
    }

    private var greenShare: Int {
        guard total > 0 else { return 0 }
        let green = sources.filter { $0.category == .groen }.reduce(0) { $0 + $1.volumeKWh }
        return Int((green / total * 100).rounded())
    }

    var body: some View {
        let selected = sources.first { $0.typeId == selectedId }
        ZStack {
            Circle()
                .stroke(Palette.rule2, lineWidth: stroke)
            ForEach(segments) { segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(segment.source.color, style: StrokeStyle(lineWidth: stroke, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .opacity(selectedId != nil && selectedId != segment.source.typeId ? 0.32 : 1)
            }
            center(selected: selected)
        }
        .padding(stroke / 2)
        .frame(width: size, height: size)
        .contentShape(Circle())
        .onTapGesture(coordinateSpace: .local) { location in
            if let id = segmentId(at: location) { onSelect(id) }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func center(selected: SourceSlice?) -> some View {
        if let selected {
            VStack(spacing: 8) {
                Text(verbatim: DutchFormat.percent(selected.percentage))
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    Circle().fill(selected.color).frame(width: 6, height: 6)
                    Text(verbatim: selected.label)
                        .font(.system(size: 11))
                        .tracking(0.4)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                }
                .frame(maxWidth: 120)
            }
        } else {
            VStack(spacing: 2) {
                Text(verbatim: "\(greenShare)%")
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text(verbatim: "GROEN")
                    .font(.system(size: 11))
                    .tracking(2)
                    .foregroundStyle(Palette.dim)
            }
        }
    }

    private func segmentId(at location: CGPoint) -> Int? {
        let center = CGPoint(x: size / 2, y: size / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = (dx * dx + dy * dy).squareRoot()
        let radius = (size - stroke) / 2
        guard distance >= radius - stroke, distance <= radius + stroke else { return nil }
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let fraction = Double(angle / (2 * .pi))
        return segments.first { fraction >= $0.start && fraction < $0.end }?.source.typeId
            ?? segments.last?.source.typeId
    }
}
