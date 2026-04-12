import SwiftUI

struct MixAPIResponse: Codable {
    let at: String
    let mix: MixData
}

struct MixData: Codable {
    let focusTime: String
    let greenPct: Double
    let totalKWh: Double
    let sources: [SourceSlice]
}

struct SourceSlice: Codable {
    let typeId: Int
    let label: String
    let category: String
    let color: String
    let volumeKWh: Double
    let percentage: Double

    var swiftColor: Color {
        color.hasPrefix("#") ? Color(hex: color) : Color(hex: "#2B2A28")
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

func colorForGreenPct(_ pct: Int) -> Color {
    if pct < 30 { return Color(hex: "#B91C1C") }
    if pct < 50 { return Color(hex: "#D97706") }
    if pct < 70 { return Color(hex: "#65C46A") }
    return Color(hex: "#0F5132")
}

func colorForGreenPctSoft(_ pct: Int) -> Color {
    if pct < 30 { return Color(hex: "#7F1D1D") }
    if pct < 50 { return Color(hex: "#92400E") }
    if pct < 70 { return Color(hex: "#166534") }
    return Color(hex: "#0B3D2A")
}
