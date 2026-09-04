import SwiftUI

/// "Overview" section on a Home screen: a section header with a trailing link,
/// plus whatever timeline that stage uses.
///
/// The header-and-link row is identical on every stage; only the timeline below
/// it differs (Cycle and Motherhood show a numeric strip, Pregnancy shows
/// weeks, Postpartum shows four named recovery stages). The timeline is a
/// `@ViewBuilder` slot so a stage can bring its own without re-writing the
/// header — which is how Pregnancy and Postpartum ended up with a third and
/// fourth copy of it.
struct LifeStageOverviewSection<Timeline: View>: View {
    let titleKey: LocalizedStringKey
    let linkKey: LocalizedStringKey
    let linkAccessibilityIdentifier: String
    let action: () -> Void
    @ViewBuilder var timeline: Timeline

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.sm) {
            SectionHeader(titleKey) {
                Button(action: action) {
                    HStack(spacing: AYASpacing.xs) {
                        Text(linkKey)
                        HesiaIcon.caretRight.view(size: HesiaIconSize.sm)
                    }
                    .ayaTypography(.homeLink)
                    .foregroundStyle(AYAColors.emphasis)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(linkAccessibilityIdentifier)
            }

            timeline
        }
    }
}

extension LifeStageOverviewSection {
    /// Convenience for stages that use the shared numeric strip.
    init<Value: Hashable & CustomStringConvertible>(
        titleKey: LocalizedStringKey,
        linkKey: LocalizedStringKey,
        linkAccessibilityIdentifier: String,
        values: [Value],
        currentValue: Value,
        accessibilityLabelKey: LocalizedStringKey,
        theme: LifeStageDetailTheme,
        action: @escaping () -> Void
    ) where Timeline == LifeStageHorizontalTimeline<Value> {
        self.init(
            titleKey: titleKey,
            linkKey: linkKey,
            linkAccessibilityIdentifier: linkAccessibilityIdentifier,
            action: action
        ) {
            LifeStageHorizontalTimeline(
                values: values,
                currentValue: currentValue,
                accessibilityLabelKey: accessibilityLabelKey,
                activeColor: theme.timelineActive,
                inactiveColor: theme.timelineInactive,
                connectorColor: theme.timelineConnector
            )
        }
    }
}
