import SwiftUI

/// A consistent section title with an optional trailing action.
///
/// Dedups the hand-built "title + Spacer + link" rows repeated across the four
/// Home screens (e.g. "Today's meditation", "Overview" + "View calendar").
struct SectionHeader<Trailing: View>: View {
    private let titleKey: LocalizedStringKey
    private let trailing: Trailing

    init(_ titleKey: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.titleKey = titleKey
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AYASpacing.md) {
            Text(titleKey)
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: AYASpacing.sm)

            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ titleKey: LocalizedStringKey) {
        self.init(titleKey) { EmptyView() }
    }
}

#Preview {
    VStack(spacing: AYASpacing.xl) {
        SectionHeader("cycle.home.today_meditation")
        SectionHeader("cycle.home.overview") {
            Text(verbatim: "View calendar")
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.accent)
        }
    }
    .padding(AYASpacing.xl)
    .background(AYAColors.backgroundPrimary)
}
