import CoreGraphics

/// Canonical corner-radius family (design direction v2).
///
/// Replaces the long tail of literal `cornerRadius:` values (14/16/17/18/20/22/24/26/…)
/// with four intentional steps. Always pair with `.continuous` rounded rectangles.
enum AYARadius {
    /// 8 pt — badges / small chips.
    static let chip: CGFloat = 8
    /// 16 pt — inputs, buttons, CTAs, small controls.
    static let control: CGFloat = 16
    /// 22 pt — standard cards.
    static let card: CGFloat = 22
    /// 28 pt — large hero surfaces and side panels.
    static let hero: CGFloat = 28
}
