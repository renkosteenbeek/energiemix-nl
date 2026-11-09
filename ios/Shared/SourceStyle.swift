import SwiftUI

enum SourceStyle {
    static func color(for typeId: Int) -> Color {
        switch typeId {
        case 17: Color(hex: 0x1B4F7E)
        case 1: Color(hex: 0x5896D1)
        case 2: Color(hex: 0xF5B13B)
        case 25: Color(hex: 0x7C956E)
        case 18: Color(hex: 0xE07A4E)
        case 19: Palette.coal
        case 20: Color(hex: 0x8E5BA7)
        case 21: Color(hex: 0x9B7E5A)
        default: Color(hex: 0x8D95A0)
        }
    }
}

extension SourceSlice {
    var color: Color { SourceStyle.color(for: typeId) }
}
