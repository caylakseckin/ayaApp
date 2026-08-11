import SwiftUI

/// A quiet, optional handoff between adjacent HESIA life-stage experiences.
/// The whole surface is interactive so the transition remains easy to reach
/// without introducing a second visually dominant CTA on the Home screen.
struct LifeStageContinuationCard: View {
    let destination: LifeStage
    let titleKey: LocalizedStringKey
    let messageKey: LocalizedStringKey
    let actionKey: LocalizedStringKey
    let action: () -> Void

    private var theme: LifeStageDetailTheme {
        .theme(for: destination)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: AYASpacing.md) {
                transitionSymbol

                VStack(alignment: .leading, spacing: AYASpacing.xs) {
                    Text(titleKey)
                        .ayaTypography(.sectionTitle)
                        .foregroundStyle(AYAColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(messageKey)
                        .ayaTypography(.body)
                        .foregroundStyle(AYAColors.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: AYASpacing.sm) {
                        Text(actionKey)
                            .ayaTypography(.metadata)
                            .fontWeight(.semibold)

                        HesiaIcon.arrowRight.view(size: 14)
                    }
                    .foregroundStyle(AYAColors.emphasis)
                    .padding(.top, AYASpacing.xs)
                }

                Spacer(minLength: 0)
            }
            .padding(AYASpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                theme.heroSurface,
                in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                    .stroke(theme.heroBorder, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .ayaElevation(.card)
        .accessibilityIdentifier("life_stage.continuation.\(destination.rawValue)")
    }

    private var transitionSymbol: some View {
        ZStack {
            Circle()
                .fill(theme.badgeSurface)

            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AYAColors.emphasis)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}

#Preview {
    LifeStageContinuationCard(
        destination: .postpartum,
        titleKey: "pregnancy.transition.postpartum.title",
        messageKey: "pregnancy.transition.postpartum.message",
        actionKey: "pregnancy.transition.postpartum.action",
        action: {}
    )
    .padding(AYASpacing.xl)
    .background(AYAColors.backgroundPrimary)
}
