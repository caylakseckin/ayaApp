import SwiftUI

struct ContextualInfoSection: Identifiable, Sendable {
    let titleKey: String
    let itemKeys: [String]

    var id: String { titleKey }
}

struct ContextualInfoContent: Identifiable, Sendable {
    let id: String
    let titleKey: String
    var titleNumber: Int? = nil
    var introductionHeadingKey: String? = nil
    let introductionKey: String
    var sections: [ContextualInfoSection] = []
    let hesiaExplanationKey: String
    var disclaimerKey: String? = nil
    let accessibilityLabelKey: String
    var accessibilityNumber: Int? = nil
}

struct ContextualInfoButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HesiaIcon.info.view(size: 15)
                .foregroundStyle(AYAColors.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -10)
        .padding(.vertical, -8)
        .accessibilityLabel(Text(verbatim: accessibilityLabel))
    }
}

struct ContextualInfoSheet: View {
    let content: ContextualInfoContent

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: title)
                        .ayaTypography(.screenTitle)
                        .foregroundStyle(AYAColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if let headingKey = content.introductionHeadingKey {
                        Text(verbatim: localized(headingKey))
                            .ayaTypography(.sectionTitle)
                            .foregroundStyle(AYAColors.textPrimary)
                    }

                    Text(verbatim: localized(content.introductionKey))
                        .ayaTypography(.body)
                        .foregroundStyle(AYAColors.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(content.sections) { section in
                    VStack(alignment: .leading, spacing: 11) {
                        Text(verbatim: localized(section.titleKey))
                            .ayaTypography(.sectionTitle)
                            .foregroundStyle(AYAColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)

                        ForEach(section.itemKeys, id: \.self) { key in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Circle()
                                    .fill(AYAColors.primary.opacity(0.55))
                                    .frame(width: 5, height: 5)
                                    .accessibilityHidden(true)

                                Text(verbatim: localized(key))
                                    .ayaTypography(.body)
                                    .foregroundStyle(AYAColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: localized("info.common.in_hesia"))
                        .ayaTypography(.sectionTitle)
                        .foregroundStyle(AYAColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text(verbatim: localized(content.hesiaExplanationKey))
                        .ayaTypography(.body)
                        .foregroundStyle(AYAColors.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AYAColors.softPink.opacity(0.18), in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))

                if let disclaimerKey = content.disclaimerKey {
                    Text(verbatim: localized(disclaimerKey))
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    private var title: String {
        formatted(content.titleKey, number: content.titleNumber)
    }

    private func localized(_ key: String) -> String {
        selectedLanguage.localizedString(forKey: key)
    }

    private func formatted(_ key: String, number: Int?) -> String {
        let format = localized(key)
        guard let number else { return format }
        return String(format: format, locale: locale, number)
    }
}

#Preview("Contextual Info — Türkçe") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ContextualInfoSheet(content: CycleInfoProvider.content(for: .luteal))
                .environment(\.locale, Locale(identifier: "tr"))
        }
}

#Preview("Contextual Info — English") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ContextualInfoSheet(content: MotherhoodInfoProvider.content(for: .toddler))
                .environment(\.locale, Locale(identifier: "en"))
        }
}

#Preview("Postpartum Info — Large Type") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ContextualInfoSheet(content: PostpartumInfoProvider.content(for: .earlyPostpartum))
                .environment(\.dynamicTypeSize, .accessibility3)
        }
}
