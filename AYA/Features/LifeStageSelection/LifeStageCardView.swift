import SwiftUI

struct LifeStageCardView: View {
    private enum Metrics {
        static let horizontalPadding: CGFloat = 20
        static let topPadding: CGFloat = 14
        static let bottomPadding: CGFloat = 15
        static let titleWidth: CGFloat = 240
        static let titleDescriptionSpacing: CGFloat = 3
        static let descriptionLineSpacing: CGFloat = 1

        static let badgeHeight: CGFloat = 24
        static let badgeHorizontalPadding: CGFloat = AYASpacing.sm
        static let badgeContentSpacing: CGFloat = AYASpacing.xs
        static let badgeCornerRadius: CGFloat = AYARadius.chip
    }

    let stage: LifeStage
    let isSelected: Bool
    let isPremiumUnlocked: Bool
    let usesCompactMetrics: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var theme: LifeStageTheme { .theme(for: stage) }
    private var usesExpandedLayout: Bool { dynamicTypeSize.isAccessibilitySize }
    private var cardMinHeight: CGFloat { usesCompactMetrics ? 120 : 132 }

    var body: some View {
        Button(action: action) {
            Group {
                if usesExpandedLayout {
                    ZStack(alignment: .topLeading) {
                        cardBackground
                        content(descriptionWidth: nil)
                    }
                    .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            cardBackground
                            motif
                            content(descriptionWidth: geometry.size.width * 0.5)
                        }
                    }
                    .frame(height: cardMinHeight)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                    .stroke(
                        isSelected
                            ? theme.accentColor(for: colorScheme)
                            : theme.borderColor(for: colorScheme),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                if showsPremiumBadge {
                    premiumBadge
                        .padding(.top, AYASpacing.md)
                        .padding(.trailing, AYASpacing.md)
                } else if isSelected {
                    selectionIndicator
                }
            }
        }
        .buttonStyle(.plain)
        .ayaSelectionGlow(color: theme.accentColor(for: colorScheme), isActive: isSelected)
        .ayaCardShadow()
        .accessibilityIdentifier("life_stage.card.\(stage.rawValue)")
        .accessibilityLabel(stage.titleKey)
        .accessibilityHint(stage.descriptionKey)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var cardBackground: some View {
        if colorScheme == .dark {
            ZStack {
                AYAColors.surfaceElevated
                theme.darkSurfaceTint
            }
        } else if stage == .cycle {
            LinearGradient(colors: [theme.background, theme.secondaryBackground], startPoint: .top, endPoint: .bottom)
        } else {
            theme.background
        }
    }

    private func content(descriptionWidth: CGFloat?) -> some View {
        titleAndDescription(descriptionWidth: descriptionWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, Metrics.horizontalPadding)
            .padding(.top, Metrics.topPadding)
            .padding(.bottom, Metrics.bottomPadding)
    }

    private func titleAndDescription(descriptionWidth: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: Metrics.titleDescriptionSpacing) {
            Text(stage.titleKey)
                .ayaTypography(stage == .motherhood03 ? .stageCardTitleLong : .stageCardTitle)
                .foregroundStyle(theme.titleColor(for: colorScheme))
                .lineLimit(usesExpandedLayout ? nil : 1)
                .minimumScaleFactor(usesExpandedLayout ? 1 : 0.9)
                .allowsTightening(!usesExpandedLayout)

            Text(stage.descriptionKey)
                .ayaTypography(.body)
                .foregroundStyle(theme.bodyColor(for: colorScheme))
                .lineSpacing(Metrics.descriptionLineSpacing)
                .lineLimit(usesExpandedLayout ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: descriptionWidth ?? .infinity, alignment: .leading)
        }
        .frame(
            maxWidth: usesExpandedLayout ? .infinity : Metrics.titleWidth,
            alignment: .leading
        )
    }

    private var showsPremiumBadge: Bool {
        stage.isPremium && !isPremiumUnlocked
    }

    private var premiumBadge: some View {
        HStack(spacing: Metrics.badgeContentSpacing) {
            HesiaIcon.lock.view(size: 11)
            Text(stage.badgeKey)
        }
        .ayaTypography(.badge)
        .foregroundStyle(theme.badgeForeground(for: colorScheme))
        .padding(.horizontal, Metrics.badgeHorizontalPadding)
        .frame(height: Metrics.badgeHeight)
        .background(
            theme.badgeBackground(for: colorScheme),
            in: RoundedRectangle(cornerRadius: Metrics.badgeCornerRadius, style: .continuous)
        )
    }

    private var selectionIndicator: some View {
        HesiaIcon.check.view(size: 11)
            .foregroundStyle(
                colorScheme == .dark
                    ? AYAColors.onAccent
                    : (stage == .cycle ? AYAColors.secondary : AYAColors.surface)
            )
            .frame(width: 24, height: 24)
            .background(theme.accentColor(for: colorScheme), in: Circle())
            .padding(11)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var motif: some View {
        Group {
            switch stage {
            case .cycle: CycleMotifView()
            case .pregnancy: PregnancyMotifView()
            case .birthMoment: BirthMomentMotifView()
            case .postpartum: PostpartumMotifView()
            case .motherhood03: MotherhoodMotifView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .opacity(
            colorScheme == .dark
                ? theme.darkMotifOpacity
                : (usesExpandedLayout ? 0.72 : 1)
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct BirthMomentMotifView: View {
    var body: some View {
        Image("stage_birth_moment")
            .resizable()
            .scaledToFill()
            .scaleEffect(x: 1.05, y: 1.15)
            .accessibilityHidden(true)
    }
}
