import SwiftUI

/// Shared shell for the four life-stage Home screens.
///
/// The greeting and the profile button used to sit inside each screen's
/// `ScrollView`, so scrolling down hid the only entry point to Settings and
/// Themes. They now live in a pinned `safeAreaInset`, which also gives every
/// Home screen the same gutter and vertical rhythm.
struct HomeScreenScaffold<Header: View, Content: View>: View {
    private let contentTopPadding: CGFloat
    private let header: Header
    private let content: Content

    init(
        contentTopPadding: CGFloat = AYASpacing.sm,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.contentTopPadding = contentTopPadding
        self.header = header()
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AYALayout.sectionSpacing) {
                content
            }
            .hesiaScreenPadding()
            .padding(.top, contentTopPadding)
            .padding(.bottom, AYALayout.screenBottomPadding)
            .frame(maxWidth: AYALayout.readableContentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .hesiaScreenPadding()
                .padding(.top, AYASpacing.sm)
                .padding(.bottom, AYASpacing.md)
                .frame(maxWidth: AYALayout.readableContentMaxWidth)
                .frame(maxWidth: .infinity)
                .background {
                    // Content scrolls under the header rather than being cut
                    // off by an opaque block.
                    Rectangle()
                        .fill(.bar)
                        .ignoresSafeArea(edges: .top)
                        .accessibilityHidden(true)
                }
        }
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
    }
}

/// Greeting + supporting line + profile button, shared by all four Home
/// screens. `detail` carries the stage-specific subtitle (cycle day, pregnancy
/// week, postpartum day) and any trailing info button.
struct HomeHeader<Detail: View>: View {
    let greeting: String
    let userInitial: String
    let showsProfileButton: Bool
    let openSettings: () -> Void
    @ViewBuilder var detail: Detail

    var body: some View {
        HStack(alignment: .center, spacing: AYASpacing.md) {
            VStack(alignment: .leading, spacing: AYASpacing.xs) {
                Text(verbatim: greeting)
                    .ayaTypography(.homeGreeting)
                    .foregroundStyle(AYAColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                detail
            }

            Spacer(minLength: AYASpacing.sm)

            if showsProfileButton {
                AYAProfileButton(initial: userInitial, action: openSettings)
            }
        }
    }
}

/// The "Day 14" / "Week 19" line under the greeting.
struct HomeHeaderDetail: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .ayaTypography(.homeSupporting)
            .foregroundStyle(AYAColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.numericText())
    }
}
