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
        .padding(.horizontal, 22)
        .padding(.bottom, 4)
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
