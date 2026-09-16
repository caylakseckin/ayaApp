import SwiftUI

struct OfflineMeditationOnboardingView: View {
    let completion: () -> Void

    @AppStorage(OfflineMeditationPreferenceKeys.isEnabled) private var isEnabled = false

    var body: some View {
        HesiaCenteredScrollView {
            VStack(spacing: AYASpacing.xl) {

                HesiaIcon.headphones.view(size: 48)
                    .foregroundStyle(AYAColors.accent)
                    .frame(width: 112, height: 112)
                    .background(AYAColors.accentSoft, in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: AYASpacing.md) {
                    Text("onboarding.offline.title")
                        .ayaTypography(.screenTitle)
                        .foregroundStyle(AYAColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text("onboarding.offline.description")
                        .ayaTypography(.body)
                        .foregroundStyle(AYAColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: AYASpacing.lg) {
                    OnboardingBenefitRow(
                        icon: .check,
                        titleKey: "onboarding.offline.benefit.three_days.title",
                        descriptionKey: "onboarding.offline.benefit.three_days.description"
                    )
                    OnboardingBenefitRow(
                        icon: .lock,
                        titleKey: "onboarding.offline.benefit.cleanup.title",
                        descriptionKey: "onboarding.offline.benefit.cleanup.description"
                    )
                }
                .padding(AYASpacing.xl)
                .background(
                    AYAColors.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                        .stroke(AYAColors.separator, lineWidth: 1)
                }
                .ayaElevation(.card)

            }
            .hesiaScreenPadding()
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: AYASpacing.sm) {
                Button("onboarding.offline.enable") {
                    isEnabled = true
                    completion()
                }
                .buttonStyle(.appPrimary)
                .accessibilityIdentifier("offline.onboarding.enable.button")

                OnboardingSecondaryButton(
                    titleKey: "onboarding.offline.skip",
                    accessibilityIdentifier: "offline.onboarding.skip.button"
                ) {
                    isEnabled = false
                    completion()
                }
            }
            .hesiaBottomBar()
        }
    }

}

#Preview("Offline — Türkçe") {
    OfflineMeditationOnboardingView {}
        .environment(\.locale, Locale(identifier: "tr"))
}

#Preview("Offline — English") {
    OfflineMeditationOnboardingView {}
        .environment(\.locale, Locale(identifier: "en"))
}
