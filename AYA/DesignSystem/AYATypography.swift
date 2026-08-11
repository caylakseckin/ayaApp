import SwiftUI

enum AYATypography {
    enum Role {
        case homeGreeting
        case homeSectionHeading
        case homeInsightTitle
        case homeMeditationTitle
        case homeMetricValue
        case homeBody
        case homeSupporting
        case homeMetadata
        case homeBadge
        case homeLink
        case homeCTA

        // MARK: - v2 general roles (premium-calm direction)
        // Scaling, app-wide roles that replace raw `.system(size:)` sites.
        case screenTitle
        case sectionTitle
        case playerTitle
        case body
        case metadata
        case button

        fileprivate var baseSize: CGFloat {
            switch self {
            case .homeGreeting: 26
            case .homeSectionHeading: 16
            case .homeInsightTitle: 19
            case .homeMeditationTitle: 18.5
            case .homeMetricValue: 23.25
            case .homeBody, .homeSupporting: 12
            case .homeMetadata, .homeBadge: 11
            case .homeLink: 12
            case .homeCTA: 14
            case .screenTitle: 26
            case .sectionTitle: 16
            case .playerTitle: 30
            case .body: 15
            case .metadata: 13
            case .button: 16
            }
        }

        fileprivate var relativeTextStyle: Font.TextStyle {
            switch self {
            case .homeGreeting: .title
            case .homeInsightTitle: .title3
            case .homeMeditationTitle: .title3
            case .homeMetricValue: .title2
            case .homeBody, .homeSupporting, .homeCTA: .body
            case .homeMetadata, .homeBadge, .homeLink: .footnote
            case .homeSectionHeading: .headline
            case .screenTitle: .title
            case .sectionTitle: .headline
            case .playerTitle: .largeTitle
            case .body, .button: .body
            case .metadata: .footnote
            }
        }

        fileprivate var design: Font.Design {
            switch self {
            case .homeGreeting, .homeInsightTitle, .homeMeditationTitle, .homeMetricValue,
                    .screenTitle, .playerTitle:
                .serif
            default:
                .default
            }
        }

        fileprivate var weight: Font.Weight {
            switch self {
            case .homeGreeting, .homeSectionHeading, .homeInsightTitle, .homeMeditationTitle,
                    .homeMetricValue,
                    .homeBadge, .homeCTA,
                    .screenTitle, .sectionTitle, .playerTitle, .button:
                .semibold
            case .homeLink, .homeMetadata, .homeSupporting, .metadata:
                .medium
            case .homeBody, .body:
                .regular
            }
        }
    }

    // Satoshi and Nyght Serif are not bundled yet. These role-based APIs use
    // accessible system fallbacks until verified PostScript names are available.
    static func editorial(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func ui(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static let screenTitle = editorial(size: 26, weight: .semibold)
    static let cardTitle = editorial(size: 23.25, weight: .semibold)
    static let longCardTitle = editorial(size: 21, weight: .semibold)
    static let body = ui(size: 12)
    static let button = ui(size: 8.8, weight: .medium)
    static let badge = ui(size: 7.7, weight: .medium)
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
