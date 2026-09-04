import SwiftUI

struct OnboardingReturnToThemesButton: View {
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("onboarding.return_to_themes")
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textSecondary)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

/// One "why this is worth turning on" line in an onboarding benefit card.
/// Shared by the Face ID and offline-listening screens, which were previously
/// two copies of the same view.
struct OnboardingBenefitRow: View {
    let icon: HesiaIcon
    let titleKey: LocalizedStringKey
    let descriptionKey: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: AYASpacing.md) {
            icon.view(size: HesiaIconSize.md)
                .foregroundStyle(AYAColors.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: AYASpacing.xs) {
                Text(titleKey)
                    .ayaTypography(.settingsRowTitle)
                    .foregroundStyle(AYAColors.textPrimary)

                Text(descriptionKey)
                    .ayaTypography(.settingsRowValue)
                    .foregroundStyle(AYAColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Quiet "skip / not now" action sitting under a primary onboarding CTA.
struct OnboardingSecondaryButton: View {
    let titleKey: LocalizedStringKey
    var isEnabled: Bool = true
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(titleKey)
                .ayaTypography(.settingsRowTitle)
                .foregroundStyle(AYAColors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct OnboardingPrivacyNotice: View {
    let descriptionKey: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: AYASpacing.md) {
            HesiaIcon.lock.view(size: 18)
                .foregroundStyle(AYAColors.primary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: AYASpacing.xs) {
                Text("onboarding.privacy.title")
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.textPrimary)

                Text(descriptionKey)
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AYASpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AYAColors.tertiary.opacity(0.34),
            in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}
