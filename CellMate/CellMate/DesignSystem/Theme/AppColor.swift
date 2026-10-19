import SwiftUI

/// Every colour in the app. Never type a hex value anywhere else.
/// Light and Dark values come from the Figma screens.
/// Dark Medium and High risk were not designed, so they are proposed values.
enum AppColor {
    // Surfaces
    static let background = Color(light: 0xF2F2F7, dark: 0x000000)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let track = Color(light: 0xE5E5EA, dark: 0x2A2A2C)

    // Text
    static let textPrimary = Color(light: 0x111111, dark: 0xF5F5F7)
    static let textSecondary = Color(light: 0x636366, dark: 0xAEAEB2)

    // Brand
    static let brand = Color(light: 0x0B7A75, dark: 0x0B7A75)       // fills: buttons, status card
    static let onBrand = Color(light: 0xFFFFFF, dark: 0xFFFFFF)     // text and icons on a brand fill
    static let accent = Color(light: 0x0B7A75, dark: 0x65D5CD)      // links, icons, active tab
    static let brandTint = Color(light: 0xE5F3F1, dark: 0x253334)   // icon tiles, secondary button

    // Risk (text colour on a matching background)
    static let lowText = Color(light: 0x187A33, dark: 0x8EDDA4)
    static let lowBackground = Color(light: 0xE2F5E7, dark: 0x143823)
    static let mediumText = Color(light: 0xA65A00, dark: 0xFF9F0A)
    static let mediumBackground = Color(light: 0xFFF0D6, dark: 0x3A2A0A)
    static let highText = Color(light: 0xC8102E, dark: 0xFF6B60)
    static let highBackground = Color(light: 0xFFE3E7, dark: 0x3D1416)

    // Destructive actions (Retire battery, Delete data)
    static let destructive = Color(light: 0xC8102E, dark: 0xC8102E)
}
