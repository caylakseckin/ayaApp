import SwiftUI

/// Canonical elevation (shadow) scale.
///
/// Warm, low-opacity shadows only — never harsh black. One source of truth so
/// every elevated surface reads as part of the same system. In dark mode,
/// elevation is expressed by lightening the surface rather than by heavy shadow.
enum AYAElevation {
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        /// Resting cards (matches the legacy `ayaCardShadow()`).
        static let card = Shadow(color: AYAColors.shadow, radius: 9, x: 0, y: 5)
        /// Focal / raised controls (e.g. the player transport button).
        static let raised = Shadow(color: AYAColors.strongShadow, radius: 12, x: 0, y: 5)
        /// Side panels / drawers.
        static let panel = Shadow(color: AYAColors.strongShadow, radius: 22, x: -8, y: 0)
    }
}

extension View {
    /// Applies a named elevation from the `AYAElevation` scale.
    func ayaElevation(_ shadow: AYAElevation.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
