import SwiftUI
import UIKit

enum Palette {
    static let background = adaptive(light: 0xFAFAF7, dark: 0x141413)
    static let ink = adaptive(light: 0x0B0B0A, dark: 0xE8E6E1)
    static let dim = adaptive(light: 0x6B6660, dark: 0x9C9891, lightHighContrast: 0x4A4641, darkHighContrast: 0xC4C0B9)
    static let dim2 = adaptive(light: 0x97928A, dark: 0x706C66, lightHighContrast: 0x5F5A54, darkHighContrast: 0xA5A19A)
    static let rule = adaptive(light: 0xE6E2D8, dark: 0x2A2926, lightHighContrast: 0xC9C4B8, darkHighContrast: 0x45433F)
    static let rule2 = adaptive(light: 0xEFEBE0, dark: 0x1F1F1D, lightHighContrast: 0xDDD8CB, darkHighContrast: 0x33322F)
    static let chip = adaptive(light: 0xF2EEE4, dark: 0x252422)
    static let emptyBar = adaptive(light: 0xE0DBCC, dark: 0x2A2926, lightHighContrast: 0xC9C4B8, darkHighContrast: 0x45433F)
    static let coal = adaptive(light: 0x2B2A28, dark: 0x6B6862)
    static let forecastShade = adaptive(light: 0x0B0B0A, dark: 0xE8E6E1, alpha: 0.04)

    static func adaptive(
        light: UInt32,
        dark: UInt32,
        lightHighContrast: UInt32? = nil,
        darkHighContrast: UInt32? = nil,
        alpha: CGFloat = 1
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHighContrast = traits.accessibilityContrast == .high
            let hex: UInt32
            switch (isDark, isHighContrast) {
            case (false, false): hex = light
            case (false, true): hex = lightHighContrast ?? light
            case (true, false): hex = dark
            case (true, true): hex = darkHighContrast ?? dark
            }
            return UIColor(hex: hex, alpha: alpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
