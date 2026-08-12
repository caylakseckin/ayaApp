import SwiftUI

struct OfflineMeditationOnboardingView: View {
    let completion: () -> Void

    @AppStorage(OfflineMeditationPreferenceKeys.isEnabled) private var isEnabled = false

    var body: some View {
        ScrollView {
            VStack(spacing: AYASpacing.xl) {
                Spacer(minLength: AYASpacing.xxxl)

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
                    benefitRow(
                        icon: .check,
                        title: "onboarding.offline.benefit.three_days.title",
                        description: "onboarding.offline.benefit.three_days.description"
                    )
                    benefitRow(
                        icon: .lock,
                        title: "onboarding.offline.benefit.cleanup.title",
                        description: "onboarding.offline.benefit.cleanup.description"
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

                Spacer(minLength: AYASpacing.xxl)
            }
            .padding(.horizontal, AYASpacing.xl)
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

                Button {
                    isEnabled = false
                    completion()
                } label: {
                    Text("onboarding.offline.skip")
                        .font(AYATypography.ui(size: 15, weight: .medium))
                        .foregroundStyle(AYAColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("offline.onboarding.skip.button")
            }
            .frame(maxWidth: 512)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AYASpacing.xl)
            .padding(.top, AYASpacing.sm)
            .padding(.bottom, AYASpacing.md)
            .background(AYAColors.backgroundPrimary.opacity(0.96))
        }
    }

    private func benefitRow(
        icon: HesiaIcon,
        title: LocalizedStringKey,
        description: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: AYASpacing.md) {
            icon.view(size: 19)
                .foregroundStyle(AYAColors.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: AYASpacing.xs) {
                Text(title)
                    .font(AYATypography.ui(size: 15, weight: .medium))
                    .foregroundStyle(AYAColors.textPrimary)

                Text(description)
                    .font(AYATypography.ui(size: 13))
                    .foregroundStyle(AYAColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
