import SwiftUI

struct PregnancyWeekInfoPresentation: Identifiable {
    let week: Int
    let language: AppLanguage
    let content: PregnancyWeekInfoContent?

    var id: String { "pregnancy.week.\(week).\(language.rawValue)" }
}

struct PregnancyWeekInfoSheet: View {
    let presentation: PregnancyWeekInfoPresentation

    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AYASpacing.xl) {
                Text(verbatim: weekTitle)
                    .ayaTypography(.screenTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if let content = presentation.content {
                    informationSection(title: content.babyTitle, body: content.baby)
                    informationSection(title: content.bodyTitle, body: content.body)

                    informationSection(title: content.experienceTitle, body: content.experience)
                        .padding(AYASpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            AYAColors.accentSoft,
                            in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                        )

                    Divider()
                        .overlay(AYAColors.separator)

                    Text(verbatim: content.disclaimer)
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textTertiary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(verbatim: localized("pregnancy.week_info.unavailable"))
                        .ayaTypography(.body)
                        .foregroundStyle(AYAColors.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, AYASpacing.xl)
            .padding(.top, AYASpacing.md)
            .padding(.bottom, AYASpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func informationSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: AYASpacing.sm) {
            Text(verbatim: title)
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: body)
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var weekTitle: String {
        let format = localized("pregnancy.week_info.title")
        return String(format: format, locale: locale, presentation.week)
    }

    private func localized(_ key: String) -> String {
        presentation.language.localizedString(forKey: key)
    }
}

#Preview("Week 1 — Türkçe — Small iPhone", traits: .fixedLayout(width: 320, height: 568)) {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PregnancyWeekInfoSheet(
                presentation: .init(
                    week: 1,
                    language: .turkish,
                    content: PregnancyWeekInfoRepository.shared.info(for: 1, language: .turkish)
                )
            )
        }
}

#Preview("Week 18 — English") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PregnancyWeekInfoSheet(
                presentation: .init(
                    week: 18,
                    language: .english,
                    content: PregnancyWeekInfoRepository.shared.info(for: 18, language: .english)
                )
            )
        }
}

#Preview("Week 40 — Türkçe — Large Type") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PregnancyWeekInfoSheet(
                presentation: .init(
                    week: 40,
                    language: .turkish,
                    content: PregnancyWeekInfoRepository.shared.info(for: 40, language: .turkish)
                )
            )
            .environment(\.dynamicTypeSize, .accessibility3)
        }
}
