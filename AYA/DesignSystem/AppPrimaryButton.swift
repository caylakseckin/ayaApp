import SwiftUI

/// Primary call-to-action button style: full-width, deep-plum fill, warm-white label.
///
/// Replaces the hand-rolled `.buttonStyle(.plain)` + inline `RoundedRectangle`
/// CTAs scattered across the app. Handles pressed and disabled states centrally.
struct AppPrimaryButtonStyle: ButtonStyle {
    var fill: Color = AYAColors.emphasis
    var minHeight: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, fill: fill, minHeight: minHeight)
    }

    private struct StyleBody: View {
        let configuration: ButtonStyleConfiguration
        let fill: Color
        let minHeight: CGFloat
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .ayaTypography(.button)
                .foregroundStyle(AYAColors.onAccent)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(
                    fill,
                    in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                )
                .opacity(isEnabled ? (configuration.isPressed ? 0.92 : 1) : 0.45)
                .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.99 : 1))
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.12),
                    value: configuration.isPressed
                )
        }
    }
}

extension ButtonStyle where Self == AppPrimaryButtonStyle {
    /// Full-width plum CTA. Usage: `.buttonStyle(.appPrimary)`.
    static var appPrimary: AppPrimaryButtonStyle { AppPrimaryButtonStyle() }

    /// Full-width CTA with a custom fill (e.g. a stage accent).
    static func appPrimary(fill: Color) -> AppPrimaryButtonStyle {
        AppPrimaryButtonStyle(fill: fill)
    }
}
