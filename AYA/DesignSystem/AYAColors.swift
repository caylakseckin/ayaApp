import SwiftUI
import UIKit

enum AYAColors {
    // MARK: - Base brand palette (appearance-aware)
    // Dark values are warm — never pure black — and the mauve accent is lifted so
    // it keeps contrast on dark surfaces.
    static let primary = Color(light: 0x99627A, dark: 0xCE9EB6)
    static let secondary = Color(light: 0x6C2645, dark: 0xC98BA6)
    static let tertiary = Color(light: 0xFEEBC8, dark: 0x5A4A38)
    static let softPink = Color(light: 0xECC0D3, dark: 0x5A3B48)
    static let background = Color(light: 0xF9F5F6, dark: 0x171215)
    static let surface = Color(light: 0xFFFFFF, dark: 0x241C24)

    // Warm neutral informational hierarchy.
    static let informationalPrimary = Color(light: 0x302A2D, dark: 0xF2EAEE)
    static let informationalSecondary = Color(light: 0x6F656A, dark: 0xB7A8B0)
    static let informationalTertiary = Color(light: 0x786D72, dark: 0x9C8F96)

    // Legacy text roles now point at the v2 warm-ink roles for consistency.
    static let primaryText = textPrimary
    static let secondaryText = textSecondary
    static let divider = secondary.opacity(0.12)
    static let border = secondary.opacity(0.14)
    // Scrim behind the settings drawer — darkens in both appearances.
    static let overlay = Color(light: 0x2A1520, dark: 0x000000).opacity(0.32)
    static let shadow = Color(light: 0x6C2645, dark: 0x000000).opacity(0.07)
    static let strongShadow = Color(light: 0x6C2645, dark: 0x000000).opacity(0.16)

    static let selectionBackground = softPink.opacity(0.42)
    static let pregnancySurface = tertiary.opacity(0.58)
    static let postpartumSurface = softPink.opacity(0.44)
    static let motherhoodSurface = primary.opacity(0.10)

    // Contextual Home hero surfaces.
    static let cycleHeroSurface = softPink.opacity(0.14)
    static let pregnancyHeroSurface = tertiary.opacity(0.18)
    static let postpartumHeroSurface = softPink.opacity(0.10)
    static let motherhoodHeroSurface = primary.opacity(0.045)

    // Compatibility alias for existing reusable surfaces.
    static let cardSurface = surface

    // MARK: - v2 semantic roles (premium-calm, appearance-aware)

    /// Warm near-black ink (light) / warm off-white (dark) for body/primary text.
    static let textPrimary = Color(light: 0x241C21, dark: 0xF2EAEE)
    static let textSecondary = Color(light: 0x6E616A, dark: 0xB7A8B0)
    static let textTertiary = Color(light: 0x9C8F96, dark: 0x8A7C84)

    /// Warm bone canvas (light) / warm near-black (dark).
    static let backgroundPrimary = Color(light: 0xF7F3EF, dark: 0x141013)
    static let backgroundSecondary = Color(light: 0xEFE7E0, dark: 0x1C161A)
    /// Elevated surface (paired with a soft shadow, no border).
    static let surfaceElevated = Color(light: 0xFFFFFF, dark: 0x2A222A)

    /// Brand mauve, used as the accent.
    static let accent = primary
    static let accentPressed = Color(light: 0x85526A, dark: 0xB487A0)
    /// Soft accent tint for selected/quiet fills.
    static let accentSoft = primary.opacity(0.12)
    /// Deep plum (light) / lifted mauve (dark) — strong emphasis and primary CTAs.
    static let emphasis = secondary
    /// Foreground on `accent` / `emphasis` fills (white on dark plum / ink on light mauve).
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x1A0F14)

    /// Hairline separator. Warm and low-contrast.
    static let separator = secondary.opacity(0.10)

    static let success = Color(light: 0x4E7A5B, dark: 0x8FBF9C)
    static let warning = Color(light: 0xB07D3C, dark: 0xE0B36A)
    static let error = Color(light: 0xB24A54, dark: 0xE6949C)
}

extension Color {
    /// Solid color from a 24-bit RGB hex value.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Appearance-aware color: resolves `light` in Light Mode and `dark` in Dark Mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
