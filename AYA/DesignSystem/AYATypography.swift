import SwiftUI

enum AYATypography {
    enum Role {
        case homeGreeting
        case homeSectionHeading
        case homeInsightTitle
        case homeMeditationTitle
        case homeMeditationDescription
        case homeMetricValue
        case homeBody
        case homeSupporting
        case homeMetadata
        case homeBadge
        case homeLink
        case homeCTA
        /// Large editorial week numeral anchoring the Pregnancy journey hero.
        /// Büyük ordinal hero metriği (gebelik haftası, lohusalık günü).
        case heroMetricValue
        /// Large editorial day numeral anchoring the Postpartum recovery hero.

        // MARK: - v2 general roles (premium-calm direction)
        // Scaling, app-wide roles that replace raw `.system(size:)` sites.
        case screenTitle
        case sectionTitle
        case playerTitle
        case body
        case metadata
        case button

        // MARK: - v3 roles
        // Added so that settings rows, section labels, badges and prices stop
        // reaching for the non-scaling `AYATypography.ui(size:)` factory.
        /// Leading label of a settings / list row.
        case settingsRowTitle
        /// Supporting value under a settings row title.
        case settingsRowValue
        /// Uppercase group label above a settings section.
        case sectionLabel
        /// Text inside a capsule or chip.
        case badge
        /// Store price shown against a purchase plan.
        case price
        /// Title on a life-stage selection card.
        case stageCardTitle
        /// Title on a life-stage selection card whose name runs long.
        case stageCardTitleLong

        fileprivate var baseSize: CGFloat {
            switch self {
            case .homeGreeting: 26
            case .homeSectionHeading: 16
            case .homeInsightTitle: 19
            case .homeMeditationTitle: 18.5
            case .homeMeditationDescription: 13
            case .homeMetricValue: 23.25
            // v3: raised off the 11/12 pt floor so body copy reads as body copy.
            case .homeBody: 14
            case .homeSupporting: 13
            case .homeMetadata: 12
            case .homeBadge: 11
            case .homeLink: 12
            case .homeCTA: 14
            case .heroMetricValue: 58
            case .screenTitle: 26
            case .sectionTitle: 16
            case .playerTitle: 30
            case .body: 15
            case .metadata: 13
            case .button: 16
            case .settingsRowTitle: 15
            case .settingsRowValue: 13
            case .sectionLabel: 13
            case .badge: 11
            case .price: 17
            case .stageCardTitle: 23.25
            case .stageCardTitleLong: 21
            }
        }

        fileprivate var relativeTextStyle: Font.TextStyle {
            switch self {
            case .homeGreeting: .title
            case .heroMetricValue: .largeTitle
            case .homeInsightTitle: .title3
            case .homeMeditationTitle: .title3
            case .homeMetricValue: .title2
            case .homeBody, .homeSupporting, .homeMeditationDescription, .homeCTA: .body
            case .homeMetadata, .homeBadge, .homeLink: .footnote
            case .homeSectionHeading: .headline
            case .screenTitle: .title
            case .sectionTitle: .headline
            case .playerTitle: .largeTitle
            case .body, .button: .body
            case .metadata: .footnote
            case .settingsRowTitle, .price: .body
            case .settingsRowValue, .sectionLabel: .footnote
            case .badge: .caption
            case .stageCardTitle, .stageCardTitleLong: .title2
            }
        }

        fileprivate var design: Font.Design {
            switch self {
            case .homeGreeting, .homeInsightTitle, .homeMeditationTitle, .homeMetricValue,
                    .heroMetricValue,
                    .screenTitle, .playerTitle, .stageCardTitle, .stageCardTitleLong:
                .serif
            default:
                .default
            }
        }

        fileprivate var weight: Font.Weight {
            switch self {
            case .homeGreeting, .homeSectionHeading, .homeInsightTitle, .homeMeditationTitle,
                    .homeMetricValue,
                    .heroMetricValue,
                    .homeBadge, .homeCTA,
                    .screenTitle, .sectionTitle, .playerTitle, .button,
                    .badge, .price, .stageCardTitle, .stageCardTitleLong:
                .semibold
            case .homeLink, .homeMetadata, .homeSupporting, .metadata,
                    .settingsRowTitle, .sectionLabel:
                .medium
            case .homeBody, .homeMeditationDescription, .body, .settingsRowValue:
                .regular
            }
        }
    }

    // Satoshi and Nyght Serif are not bundled yet. These role-based APIs use
    // accessible system fallbacks until verified PostScript names are available.
    //
    // IMPORTANT: `editorial` and `ui` produce **non-scaling** fonts. They exist
    // only for fixed-metric glyphs (the welcome wordmark, the digit baked into
    // the seek icon) where Dynamic Type would break the artwork. Never use them
    // for text — use `.ayaTypography(_:)` with a `Role` so the text scales.
    static func editorial(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func ui(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

private struct AYAScaledTypographyModifier: ViewModifier {
    let role: AYATypography.Role
    @ScaledMetric private var scaledSize: CGFloat

    init(role: AYATypography.Role) {
        self.role = role
        _scaledSize = ScaledMetric(
            wrappedValue: role.baseSize,
            relativeTo: role.relativeTextStyle
        )
    }

    func body(content: Content) -> some View {
        content.font(
            .system(
                size: scaledSize,
                weight: role.weight,
                design: role.design
            )
        )
    }
}

extension View {
    func ayaTypography(_ role: AYATypography.Role) -> some View {
        modifier(AYAScaledTypographyModifier(role: role))
    }
}
