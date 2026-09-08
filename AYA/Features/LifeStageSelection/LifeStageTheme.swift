import SwiftUI

struct LifeStageTheme {
    let background: Color
    let secondaryBackground: Color
    let titleColor: Color
    let bodyColor: Color
    let accentColor: Color
    let borderColor: Color
    let badgeBackground: Color
    let badgeForeground: Color
    let assetName: String
    let darkSurfaceTint: Color
    let darkMotifOpacity: Double

    func titleColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? AYAColors.textPrimary : titleColor
    }

    func bodyColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? AYAColors.textSecondary : bodyColor
    }

    func accentColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? AYAColors.accent : accentColor
    }

    func borderColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? AYAColors.separator : borderColor
    }

    func badgeBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? AYAColors.accentSoft : badgeBackground
    }

    func badgeForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? AYAColors.textSecondary : badgeForeground
    }

    static func theme(for stage: LifeStage) -> LifeStageTheme {
        switch stage {
        case .cycle:
            LifeStageTheme(
                background: AYAColors.secondary, secondaryBackground: AYAColors.primary,
                titleColor: AYAColors.surface, bodyColor: AYAColors.surface.opacity(0.88),
                accentColor: AYAColors.tertiary, borderColor: AYAColors.surface.opacity(0.14),
                badgeBackground: AYAColors.emphasis, badgeForeground: AYAColors.onAccent,
                assetName: "stage_cycle_orbit",
                darkSurfaceTint: AYAColors.secondary.opacity(0.12),
                darkMotifOpacity: 0.38
            )
        case .pregnancy:
            lightTheme(
                background: AYAColors.pregnancySurface,
                secondaryBackground: AYAColors.tertiary,
                badgeBackground: AYAColors.tertiary.opacity(0.88),
                asset: "stage_pregnancy_sprout",
                darkSurfaceTint: AYAColors.tertiary.opacity(0.16),
                darkMotifOpacity: 0.18
            )
        case .birthMoment:
            lightTheme(
                background: AYAColors.birthMomentSurface,
                secondaryBackground: AYAColors.softPink,
                badgeBackground: AYAColors.softPink.opacity(0.62),
                asset: "stage_birth_moment",
                darkSurfaceTint: AYAColors.softPink.opacity(0.12),
                darkMotifOpacity: 0.16
            )
        case .postpartum:
            lightTheme(
                background: AYAColors.postpartumSurface,
                secondaryBackground: AYAColors.softPink,
                badgeBackground: AYAColors.softPink.opacity(0.76),
                asset: "stage_postpartum_rest",
                darkSurfaceTint: AYAColors.softPink.opacity(0.15),
                darkMotifOpacity: 0.16
            )
        case .motherhood03:
            lightTheme(
                background: AYAColors.motherhoodSurface,
                secondaryBackground: AYAColors.primary.opacity(0.16),
                badgeBackground: AYAColors.primary.opacity(0.16),
                asset: "stage_motherhood_blocks",
                darkSurfaceTint: AYAColors.primary.opacity(0.08),
                darkMotifOpacity: 0.18
            )
        }
    }

    private static func lightTheme(
        background: Color,
        secondaryBackground: Color,
        badgeBackground: Color,
        asset: String,
        darkSurfaceTint: Color,
        darkMotifOpacity: Double
    ) -> LifeStageTheme {
        LifeStageTheme(
            background: background, secondaryBackground: secondaryBackground,
            titleColor: AYAColors.secondary, bodyColor: AYAColors.secondary.opacity(0.88),
            accentColor: AYAColors.primary, borderColor: AYAColors.border,
            badgeBackground: badgeBackground, badgeForeground: AYAColors.secondary,
            assetName: asset,
            darkSurfaceTint: darkSurfaceTint,
            darkMotifOpacity: darkMotifOpacity
        )
    }
}
