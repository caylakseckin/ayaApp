import SwiftUI

/// Canonical icon sizes.
///
/// Replaces the long tail of ad-hoc glyph sizes (9, 11, 12, 13, 14, 15, 17, 18,
/// 19, 20, 22, 25…) with four intentional steps. Chevrons and other trailing
/// accessories use `sm`, inline row icons use `md`, feature icons use `lg`, and
/// `hero` is for the large circular badges on the onboarding screens.
enum HesiaIconSize {
    /// 14 pt — trailing accessories, inline metadata glyphs.
    static let sm: CGFloat = 14
    /// 18 pt — settings rows, list leading icons.
    static let md: CGFloat = 18
    /// 22 pt — feature-level icons.
    static let lg: CGFloat = 22
    /// 48 pt — onboarding hero glyphs inside a circular surface.
    static let hero: CGFloat = 48
}

/// Typed access to the curated Phosphor Regular icons bundled with HESIA.
/// Asset names intentionally stay private so feature views depend on semantic roles.
enum HesiaIcon {
    case clock
    case headphones
    case info
    case calendar
    case caretLeft
    case caretRight
    case caretDown
    case globe
    case lock
    case check
    case notification
    case externalLink
    case arrowRight
    case close
    case seekBackward
    case seekForward
    case themes
    case email
    case document

    var image: Image {
        Image(assetName)
    }

    func view(size: CGFloat) -> HesiaIconView {
        HesiaIconView(icon: self, size: size)
    }

    private var assetName: String {
        switch self {
        case .clock: "HesiaIconClock"
        case .headphones: "HesiaIconHeadphones"
        case .info: "HesiaIconInfo"
        case .calendar: "HesiaIconCalendar"
        case .caretLeft: "HesiaIconCaretLeft"
        case .caretRight: "HesiaIconCaretRight"
        case .caretDown: "HesiaIconCaretDown"
        case .globe: "HesiaIconGlobe"
        case .lock: "HesiaIconLock"
        case .check: "HesiaIconCheck"
        case .notification: "HesiaIconBell"
        case .externalLink: "HesiaIconExternalLink"
        case .arrowRight: "HesiaIconArrowRight"
        case .close: "HesiaIconClose"
        case .seekBackward: "HesiaIconSeekBackward"
        case .seekForward: "HesiaIconSeekForward"
        case .themes: "HesiaIconThemes"
        case .email: "HesiaIconEmail"
        case .document: "HesiaIconDocument"
        }
    }
}

struct HesiaIconView: View {
    let icon: HesiaIcon
    let size: CGFloat

    var body: some View {
        icon.image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct HesiaSelectionIndicator: View {
    let isSelected: Bool
    var selectedFill: Color = AYAColors.accent
    var selectedForeground: Color = AYAColors.onAccent
    var unselectedStroke: Color = AYAColors.textTertiary

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? selectedFill : .clear)

            Circle()
                .stroke(isSelected ? .clear : unselectedStroke, lineWidth: 1.5)

            if isSelected {
                HesiaIcon.check.view(size: 11)
                    .foregroundStyle(selectedForeground)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}

struct HesiaSeekIcon: View {
    enum Direction {
        case backward
        case forward

        fileprivate var icon: HesiaIcon {
            switch self {
            case .backward: .seekBackward
            case .forward: .seekForward
            }
        }
    }

    let direction: Direction
    let seconds: Int

    var body: some View {
        ZStack {
            direction.icon.view(size: 25)

            Text(verbatim: "\(seconds)")
                .font(AYATypography.ui(size: 7.5, weight: .semibold))
                .monospacedDigit()
                .offset(y: 1)
                .accessibilityHidden(true)
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }
}
