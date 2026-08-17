import CoreGraphics

/// Canonical 8pt-based spacing scale.
///
/// Use these tokens instead of literal padding / stack `spacing:` values so the
/// app keeps a consistent vertical and horizontal rhythm. Snap any legacy odd
/// values (7, 11, 15, 17, 21, 23…) to the nearest step when migrating a screen.
enum AYASpacing {
    /// 2 pt — hairline gaps (e.g. adjacent baseline text).
    static let xxs: CGFloat = 2
    /// 4 pt — tight icon/label pairs.
    static let xs: CGFloat = 4
    /// 8 pt — default small gap.
    static let sm: CGFloat = 8
    /// 12 pt — related content spacing.
    static let md: CGFloat = 12
    /// 16 pt — standard content padding / section spacing.
    static let lg: CGFloat = 16
    /// 24 pt — screen horizontal padding / group separation.
    static let xl: CGFloat = 24
    /// 32 pt — large section separation.
    static let xxl: CGFloat = 32
    /// 48 pt — hero / top-of-screen breathing room.
    static let xxxl: CGFloat = 48
}

enum AYALayout {
    /// Keeps editorial content readable on iPad while allowing full-width iPhone layouts.
    static let readableContentMaxWidth: CGFloat = 760
}
