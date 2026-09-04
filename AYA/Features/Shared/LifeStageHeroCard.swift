import SwiftUI

// MARK: - Shared hero chrome

/// The one container every life-stage hero panel sits in.
///
/// Cycle, Pregnancy, Postpartum and Birth Moment each grew their own hero and
/// drifted into three different chromes — Pregnancy had a border and no
/// shadow, Birth Moment had neither, the other two had a shadow and no border,
/// and only one applied the minimum-height floor. Switching stages visibly
/// changed the physics of the card. Content stays bespoke per stage; the
/// surface, radius, padding and elevation come from here. The minimum-height
/// floor is deliberately *not* here — it only makes sense for the ring hero,
/// where it keeps the 112 pt ring from sitting in a cramped card. Applying it
/// to a short text-only hero (Birth Moment) just adds dead space.
private struct LifeStageHeroSurface: ViewModifier {
    let theme: LifeStageDetailTheme

    func body(content: Content) -> some View {
        content
            .padding(AYASpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                theme.heroSurface,
                in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
            )
            .ayaElevation(.card)
    }
}

extension View {
    /// Applies the shared life-stage hero chrome.
    func lifeStageHeroSurface(theme: LifeStageDetailTheme) -> some View {
        modifier(LifeStageHeroSurface(theme: theme))
    }
}

// MARK: - Shared hero pieces

/// Large ordinal metric ("21." / "18th") with its unit caption, and an optional
/// footer line. Used by the Pregnancy and Postpartum heroes.
struct HeroMetricColumn<Footer: View>: View {
    let value: String
    let unitKey: LocalizedStringKey
    let accessibilityLabelKey: LocalizedStringKey
    let accessibilityValue: String
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text(verbatim: value)
                .ayaTypography(.heroMetricValue)
                .foregroundStyle(AYAColors.accent)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.9)
                .lineLimit(1)

            Text(unitKey)
                .ayaTypography(.homeSupporting)
                .foregroundStyle(AYAColors.textSecondary)

            footer
        }
        .frame(
            minWidth: LifeStageHeroMetrics.metricColumnMinWidth,
            idealWidth: LifeStageHeroMetrics.metricColumnMinWidth,
            maxWidth: LifeStageHeroMetrics.metricColumnMaxWidth
        )
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelKey)
        .accessibilityValue(accessibilityValue)
    }
}

extension HeroMetricColumn where Footer == EmptyView {
    init(
        value: String,
        unitKey: LocalizedStringKey,
        accessibilityLabelKey: LocalizedStringKey,
        accessibilityValue: String
    ) {
        self.init(
            value: value,
            unitKey: unitKey,
            accessibilityLabelKey: accessibilityLabelKey,
            accessibilityValue: accessibilityValue,
            footer: { EmptyView() }
        )
    }
}

/// Title + supporting paragraph. Every hero has this pair; it was written four
/// times with identical styling.
struct HeroInsight: View {
    let title: String
    let message: String
    var isHeader = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.sm) {
            Text(verbatim: title)
                .ayaTypography(.homeInsightTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(isHeader ? .isHeader : [])

            Text(verbatim: message)
                .ayaTypography(.homeBody)
                .foregroundStyle(AYAColors.textSecondary)
                .lineSpacing(3)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 4)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Keeps the metric and editorial summary in one composed horizontal story.
/// The trailing summary receives layout priority so compact screens wrap copy
/// naturally without shrinking type or dropping the title below the metric.
struct HeroAdaptiveRow<Leading: View, Trailing: View>: View {
    var spacing: CGFloat = AYASpacing.md
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            leading
            trailing
                .layoutPriority(1)
        }
    }
}

/// Hairline inside a hero panel.
struct HeroDivider: View {
    let theme: LifeStageDetailTheme

    var body: some View {
        Rectangle()
            .fill(theme.heroBorder)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

// MARK: - Ring hero

/// Hero panel for stages whose progress reads as a ring (Cycle, Motherhood).
struct LifeStageHeroCard<Ring: View, Accessory: View>: View {
    private let theme: LifeStageDetailTheme
    private let badgeText: String
    private let title: String
    private let message: String
    private let ring: Ring
    private let accessory: Accessory

    init(
        theme: LifeStageDetailTheme,
        badgeText: String,
        title: String,
        message: String,
        @ViewBuilder ring: () -> Ring,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.theme = theme
        self.badgeText = badgeText
        self.title = title
        self.message = message
        self.ring = ring()
        self.accessory = accessory()
    }

    var body: some View {
        HeroAdaptiveRow(spacing: AYASpacing.lg) {
            ring
        } trailing: {
            VStack(alignment: .leading, spacing: AYASpacing.sm) {
                HStack(spacing: AYASpacing.xxs) {
                    HesiaBadge(verbatim: badgeText, prominence: .themed(theme.badgeSurface))
                    accessory
                }

                HeroInsight(title: title, message: message)
            }
        }
        .frame(minHeight: LifeStageHeroMetrics.minHeight)
        .lifeStageHeroSurface(theme: theme)
    }
}
