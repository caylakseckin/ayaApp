import SwiftUI

/// Centers short onboarding content while allowing long translations and
/// accessibility text to grow beyond the viewport and scroll naturally.
struct HesiaCenteredScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content
                    .padding(.vertical, AYASpacing.xl)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
    }
}

extension AYALayout {
    /// The one horizontal gutter for screen-level content.
    ///
    /// The app previously used five different values (16 / 18 / 20 / 22 / 24),
    /// so moving between Home and a calendar visibly shifted the content edge.
    /// Apply via `.hesiaScreenPadding()` rather than writing the literal.
    static let screenHorizontalPadding: CGFloat = 20
    /// Vertical inset from the top of a scrolling screen's content.
    static let screenTopPadding: CGFloat = AYASpacing.lg
    /// Vertical inset at the end of a scrolling screen's content.
    static let screenBottomPadding: CGFloat = AYASpacing.xl
    /// Standard gap between major sections on a screen.
    static let sectionSpacing: CGFloat = AYASpacing.xl
}

extension View {
    /// Applies the canonical screen gutter.
    func hesiaScreenPadding() -> some View {
        padding(.horizontal, AYALayout.screenHorizontalPadding)
    }

    /// Pins content to the bottom of a screen above the home indicator, on a
    /// material with a hairline separator.
    ///
    /// Replaces the six hand-rolled variants of
    /// `.background(AYAColors.backgroundPrimary.opacity(0.96…0.98))`, which
    /// produced a hard, flat cut where scrolling content disappeared behind an
    /// almost-opaque block.
    func hesiaBottomBar() -> some View {
        modifier(HesiaBottomBarModifier())
    }
}

private struct HesiaBottomBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: AYALayout.readableContentMaxWidth)
            .frame(maxWidth: .infinity)
            .hesiaScreenPadding()
            .padding(.top, AYASpacing.md)
            .padding(.bottom, AYASpacing.sm)
            .background(alignment: .top) {
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(.thinMaterial)
                    Rectangle()
                        .fill(AYAColors.separator)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
                .accessibilityHidden(true)
            }
    }
}

/// Back button + centred title used at the top of pushed screens (calendars,
/// timelines). Previously hand-rolled four times with slightly different icon
/// tints and spacings.
struct ScreenHeader: View {
    private let titleKey: LocalizedStringKey
    private let backAccessibilityKey: LocalizedStringKey
    private let dismiss: () -> Void

    init(
        _ titleKey: LocalizedStringKey,
        backAccessibilityKey: LocalizedStringKey,
        dismiss: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.backAccessibilityKey = backAccessibilityKey
        self.dismiss = dismiss
    }

    var body: some View {
        HStack(spacing: AYASpacing.md) {
            Button(action: dismiss) {
                HesiaIcon.caretLeft.view(size: HesiaIconSize.md)
                    .foregroundStyle(AYAColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(AYAColors.surfaceElevated, in: Circle())
                    .overlay { Circle().stroke(AYAColors.separator, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(backAccessibilityKey)

            Text(titleKey)
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            // Balances the back button so the title stays optically centred.
            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }
}

#Preview("Screen header") {
    VStack {
        ScreenHeader("cycle.calendar.title", backAccessibilityKey: "cycle.calendar.back") {}
        Spacer()
    }
    .hesiaScreenPadding()
    .background(AYAColors.backgroundPrimary)
}

/// Ordinal ("21." / "21st") biçimlendirici.
///
/// Gebelik ve Lohusalık hero'ları bunu birebir aynı şekilde iki kez yazmıştı ve
/// her ikisi de `NumberFormatter`'ı her body değerlendirmesinde yeniden
/// kuruyordu. Dil başına tek örnek önbelleğe alınır.
enum HesiaOrdinalFormatter {
    private static let cache = NSCache<NSString, NumberFormatter>()

    static func string(_ value: Int, language: AppLanguage) -> String {
        let key = language.rawValue as NSString
        let formatter: NumberFormatter

        if let cached = cache.object(forKey: key) {
            formatter = cached
        } else {
            formatter = NumberFormatter()
            formatter.numberStyle = .ordinal
            formatter.locale = language.locale
            cache.setObject(formatter, forKey: key)
        }

        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
