import SwiftUI

struct LifeStageDetailTheme {
    let heroSurface: Color
    let heroBorder: Color
    let badgeSurface: Color
    let ringTrack: Color
    let ringProgress: Color
    let timelineActive: Color
    let timelineInactive: Color
    let timelineConnector: Color

    static func theme(for stage: LifeStage) -> Self {
        switch stage {
        case .cycle:
            Self(
                heroSurface: AYAColors.cycleHeroSurface,
                heroBorder: AYAColors.secondary.opacity(0.14),
                badgeSurface: AYAColors.softPink.opacity(0.52),
                ringTrack: AYAColors.softPink.opacity(0.42),
                ringProgress: AYAColors.secondary,
                timelineActive: AYAColors.secondary,
                timelineInactive: AYAColors.tertiary,
                timelineConnector: AYAColors.softPink.opacity(0.48)
            )
        case .pregnancy:
            Self(
                heroSurface: AYAColors.pregnancyHeroSurface,
                heroBorder: AYAColors.primary.opacity(0.12),
                badgeSurface: AYAColors.tertiary.opacity(0.72),
                ringTrack: AYAColors.primary.opacity(0.18),
                ringProgress: AYAColors.primary,
                timelineActive: AYAColors.secondary,
                timelineInactive: AYAColors.tertiary,
                timelineConnector: AYAColors.tertiary.opacity(0.56)
            )
        case .birthMoment:
            Self(
                heroSurface: AYAColors.birthMomentHeroSurface,
                heroBorder: AYAColors.primary.opacity(0.12),
                badgeSurface: AYAColors.softPink.opacity(0.42),
                ringTrack: AYAColors.softPink.opacity(0.32),
                ringProgress: AYAColors.primary,
                timelineActive: AYAColors.secondary,
                timelineInactive: AYAColors.softPink.opacity(0.66),
                timelineConnector: AYAColors.softPink.opacity(0.42)
            )
        case .postpartum:
            Self(
                heroSurface: AYAColors.postpartumHeroSurface,
                heroBorder: AYAColors.primary.opacity(0.12),
                badgeSurface: AYAColors.softPink.opacity(0.46),
                ringTrack: AYAColors.softPink.opacity(0.38),
                ringProgress: AYAColors.primary,
                timelineActive: AYAColors.secondary,
                timelineInactive: AYAColors.softPink.opacity(0.76),
                timelineConnector: AYAColors.softPink.opacity(0.48)
            )
        case .motherhood03:
            Self(
                heroSurface: AYAColors.motherhoodHeroSurface,
                heroBorder: AYAColors.secondary.opacity(0.11),
                badgeSurface: AYAColors.tertiary.opacity(0.48),
                ringTrack: AYAColors.primary.opacity(0.14),
                ringProgress: AYAColors.primary,
                timelineActive: AYAColors.secondary,
                timelineInactive: AYAColors.tertiary.opacity(0.82),
                timelineConnector: AYAColors.primary.opacity(0.16)
            )
        }
    }
}

/// Semantic phase surfaces shared by cycle calendar states. These remain soft
/// enough for an editorial calendar while keeping the four phases distinguishable.
enum CycleCalendarPhaseTheme {
    static func surface(for phase: CyclePhase) -> Color {
        switch phase {
        case .menstrual: AYAColors.softPink.opacity(0.46)
        case .follicular: AYAColors.tertiary.opacity(0.54)
        case .ovulatory: AYAColors.primary.opacity(0.16)
        case .luteal: AYAColors.softPink.opacity(0.24)
        }
    }
}

struct LifeStageHeroBackground: View {
    let theme: LifeStageDetailTheme
    var cornerRadius: CGFloat = 26

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(theme.heroSurface)
            .allowsHitTesting(false)
    }
}

/// Shared layout metrics for the top hero/status panels used across life-stage homes.
enum LifeStageHeroMetrics {
    /// Minimum vertical presence for the hero panel. Applied via
    /// `frame(minHeight:)` (never a fixed height) so the panel still grows for
    /// long localized copy and large Dynamic Type. This taller-but-adaptive
    /// baseline lets the whole home composition fill the screen naturally,
    /// keeping the panel the primary visual anchor without artificial spacers
    /// between the meditation card and the overview. The hero content is centered
    /// within this height by the frame's default alignment.
    static let minHeight: CGFloat = 176
}
