import SwiftUI

enum GreenBand: Equatable, Sendable {
    case low
    case moderate
    case good
    case high

    init(percentage: Double) {
        switch Int(percentage.rounded()) {
        case ..<30: self = .low
        case ..<50: self = .moderate
        case ..<70: self = .good
        default: self = .high
        }
    }

    var color: Color {
        switch self {
        case .low: Color(hex: 0xB91C1C)
        case .moderate: Color(hex: 0xD97706)
        case .good: Color(hex: 0x65C46A)
        case .high: Color(hex: 0x0F5132)
        }
    }

    var labelColor: Color {
        switch self {
        case .low: Palette.adaptive(light: 0xB91C1C, dark: 0xEF4444)
        case .moderate: Palette.adaptive(light: 0xB45309, dark: 0xF59E0B)
        case .good: Palette.adaptive(light: 0x2B7F38, dark: 0x65C46A)
        case .high: Palette.adaptive(light: 0x0F5132, dark: 0x4CB782)
        }
    }

    func cardColor(increasedContrast: Bool) -> Color {
        guard increasedContrast else { return color }
        switch self {
        case .low: return Color(hex: 0xB91C1C)
        case .moderate: return Color(hex: 0xA85006)
        case .good: return Color(hex: 0x267A33)
        case .high: return Color(hex: 0x0F5132)
        }
    }

    var softColor: Color {
        switch self {
        case .low: Color(hex: 0x7F1D1D)
        case .moderate: Color(hex: 0x92400E)
        case .good: Color(hex: 0x166534)
        case .high: Color(hex: 0x0B3D2A)
        }
    }
}

struct CardGradient: View {
    private enum Style {
        case band(GreenBand)
        case custom(top: Color, bottom: Color)
    }

    private let style: Style

    @Environment(\.colorSchemeContrast) private var contrast

    static let edge = Color(hex: 0x0A0A0A)

    init(band: GreenBand) {
        style = .band(band)
    }

    init(top: Color, bottom: Color) {
        style = .custom(top: top, bottom: bottom)
    }

    static var neutral: CardGradient {
        CardGradient(top: Color(hex: 0x2A2926), bottom: Color(hex: 0x1A1A19))
    }

    private var top: Color {
        switch style {
        case .band(let band): band.cardColor(increasedContrast: contrast == .increased)
        case .custom(let top, _): top
        }
    }

    private var bottom: Color {
        switch style {
        case .band(let band): band.softColor
        case .custom(_, let bottom): bottom
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)
            let verticalScale = (1.1 * height) / (1.3 * width)
            RadialGradient(
                stops: [
                    .init(color: top, location: 0),
                    .init(color: bottom, location: 0.72 / 1.4),
                    .init(color: Self.edge, location: 1),
                ],
                center: UnitPoint(x: 0.28, y: 0),
                startRadius: 0,
                endRadius: 1.4 * 1.3 * width
            )
            .frame(width: width, height: height / verticalScale)
            .scaleEffect(x: 1, y: verticalScale, anchor: .top)
        }
    }
}
