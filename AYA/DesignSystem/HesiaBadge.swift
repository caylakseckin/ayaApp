import SwiftUI

/// Small capsule label — cycle phase, trimester, postpartum stage, "today",
/// "best value".
///
/// The app previously grew seven different capsule heights (19.8, 23, 26, 27,
/// 28, 32 and 38 pt) for the same conceptual element. Height is now derived
/// from the text so it tracks Dynamic Type instead of being pinned.
struct HesiaBadge: View {
    enum Prominence {
        /// Soft accent tint — the default for phase / stage labels.
        case soft
        /// Stage-themed fill, supplied by `LifeStageDetailTheme.badgeSurface`.
        case themed(Color)
        /// Quiet neutral fill for secondary markers such as "today".
        case neutral

        var background: Color {
            switch self {
            case .soft: AYAColors.accentSoft
            case let .themed(color): color
            case .neutral: AYAColors.surfaceElevated
            }
        }

        var foreground: Color {
            switch self {
            case .soft, .themed: AYAColors.emphasis
            case .neutral: AYAColors.textSecondary
            }
        }
    }

    private let text: Text
    private let prominence: Prominence

    init(_ titleKey: LocalizedStringKey, prominence: Prominence = .soft) {
        text = Text(titleKey)
        self.prominence = prominence
    }

    init(verbatim title: String, prominence: Prominence = .soft) {
        text = Text(verbatim: title)
        self.prominence = prominence
    }

    var body: some View {
        text
            .ayaTypography(.badge)
            .foregroundStyle(prominence.foreground)
            .padding(.horizontal, AYASpacing.md)
            .padding(.vertical, AYASpacing.sm)
            .background(prominence.background, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Badges") {
    VStack(alignment: .leading, spacing: AYASpacing.md) {
        HesiaBadge(verbatim: "Luteal faz")
        HesiaBadge(verbatim: "2. Trimester", prominence: .themed(AYAColors.tertiary.opacity(0.72)))
        HesiaBadge(verbatim: "Bugün", prominence: .neutral)
    }
    .padding(AYASpacing.xl)
    .background(AYAColors.backgroundPrimary)
}
