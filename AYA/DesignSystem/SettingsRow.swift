import SwiftUI

/// Shared building blocks for the HESIA settings drawer.
///
/// Before these existed, every row in `SettingsPanel` re-declared its own
/// background, corner radius, stroke, min-height and font — which drifted into
/// three different corner radii (16 / 18 / 22), five row heights and a set of
/// non-scaling `AYATypography.ui(size:)` fonts that ignored Dynamic Type.
/// Everything routes through here now so there is one answer to each question.
enum SettingsRowMetrics {
    /// Single row height. Comfortably above the 44 pt touch minimum and tall
    /// enough for a title + value pair at default type sizes.
    static let minHeight: CGFloat = 52
    /// Height for a row that stacks a title over a supporting value.
    static let stackedMinHeight: CGFloat = 62
    /// Width reserved for the leading icon so every label starts on one line.
    static let iconColumnWidth: CGFloat = 22
    /// Leading inset of a separator between rows, aligning it with the labels.
    static let separatorInset: CGFloat = 50
}

// MARK: - Section label

/// Uppercase group heading above a settings group.
struct SettingsSectionLabel: View {
    private let titleKey: LocalizedStringKey

    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }

    var body: some View {
        Text(titleKey)
            .ayaTypography(.sectionLabel)
            .foregroundStyle(AYAColors.textSecondary)
            .textCase(.uppercase)
            .padding(.horizontal, AYASpacing.xs)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Group container

/// Card that hosts one or more rows. Owns the single settings corner radius.
struct SettingsGroup<Content: View>: View {
    private let titleKey: LocalizedStringKey?
    private let content: Content

    init(_ titleKey: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.sm) {
            if let titleKey {
                SettingsSectionLabel(titleKey)
            }

            VStack(spacing: 0) {
                content
            }
            .background(
                AYAColors.surfaceElevated,
                in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                    .stroke(AYAColors.separator, lineWidth: 1)
            }
        }
    }
}

/// Hairline between two rows inside a `SettingsGroup`.
struct SettingsRowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(AYAColors.separator)
            .frame(height: 1)
            .padding(.leading, SettingsRowMetrics.separatorInset)
            .accessibilityHidden(true)
    }
}

// MARK: - Row content

/// The label half of a settings row: icon, title, optional supporting value.
struct SettingsRowLabel: View {
    let icon: SettingsRowIcon
    let titleKey: LocalizedStringKey
    var value: SettingsRowValue?

    var body: some View {
        HStack(spacing: AYASpacing.md) {
            icon
                .frame(width: SettingsRowMetrics.iconColumnWidth)

            if let value {
                VStack(alignment: .leading, spacing: AYASpacing.xxs) {
                    Text(titleKey)
                        .ayaTypography(.settingsRowTitle)
                        .foregroundStyle(AYAColors.textPrimary)

                    value
                        .ayaTypography(.settingsRowValue)
                        .foregroundStyle(AYAColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(titleKey)
                    .ayaTypography(.settingsRowTitle)
                    .foregroundStyle(AYAColors.textPrimary)
            }

            Spacer(minLength: AYASpacing.sm)
        }
    }
}

/// Leading glyph of a settings row — either a bundled Phosphor icon or an
/// SF Symbol, tinted consistently in both cases.
struct SettingsRowIcon: View {
    private enum Source {
        case hesia(HesiaIcon)
        case symbol(String)
    }

    private let source: Source
    private let tint: Color
    // Scales alongside the row's text. Without this the glyphs stay frozen at
    // 18 pt while the labels beside them grow, which looks broken at
    // accessibility sizes.
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = HesiaIconSize.md

    init(_ icon: HesiaIcon, tint: Color = AYAColors.accent) {
        source = .hesia(icon)
        self.tint = tint
    }

    init(symbol: String, tint: Color = AYAColors.accent) {
        source = .symbol(symbol)
        self.tint = tint
    }

    var body: some View {
        Group {
            switch source {
            case let .hesia(icon):
                icon.view(size: size)
            case let .symbol(name):
                Image(systemName: name)
                    .font(.system(size: size))
            }
        }
        .foregroundStyle(tint)
        .accessibilityHidden(true)
    }
}

/// Supporting text under a settings row title. Accepts either a localized key
/// or an already-resolved string, since some values are runtime-formatted.
struct SettingsRowValue: View {
    private enum Content {
        case key(LocalizedStringKey)
        case text(String)
    }

    private let content: Content

    init(_ key: LocalizedStringKey) { content = .key(key) }
    init(verbatim text: String) { content = .text(text) }

    var body: some View {
        switch content {
        case let .key(key): Text(key)
        case let .text(text): Text(verbatim: text)
        }
    }
}

// MARK: - Rows

/// Tappable settings row with a trailing chevron.
struct SettingsNavigationRow: View {
    let icon: SettingsRowIcon
    let titleKey: LocalizedStringKey
    var value: SettingsRowValue?
    var accessory: SettingsRowAccessory = .chevron
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AYASpacing.md) {
                SettingsRowLabel(icon: icon, titleKey: titleKey, value: value)
                accessory
            }
            .padding(.horizontal, AYASpacing.lg)
            .frame(minHeight: value == nil
                ? SettingsRowMetrics.minHeight
                : SettingsRowMetrics.stackedMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Trailing affordance of a settings row.
struct SettingsRowAccessory: View {
    enum Kind {
        case chevron
        case externalLink
        case disclosure(isExpanded: Bool)
        case checkmark
        case none
    }

    let kind: Kind

    static let chevron = SettingsRowAccessory(kind: .chevron)
    static let externalLink = SettingsRowAccessory(kind: .externalLink)
    static let checkmark = SettingsRowAccessory(kind: .checkmark)
    static let none = SettingsRowAccessory(kind: .none)

    static func disclosure(isExpanded: Bool) -> SettingsRowAccessory {
        SettingsRowAccessory(kind: .disclosure(isExpanded: isExpanded))
    }

    var body: some View {
        Group {
            switch kind {
            case .chevron:
                HesiaIcon.caretRight.view(size: HesiaIconSize.sm)
                    .foregroundStyle(AYAColors.textTertiary)
            case .externalLink:
                HesiaIcon.externalLink.view(size: HesiaIconSize.sm)
                    .foregroundStyle(AYAColors.textTertiary)
            case let .disclosure(isExpanded):
                HesiaIcon.caretDown.view(size: HesiaIconSize.sm)
                    .foregroundStyle(AYAColors.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            case .checkmark:
                HesiaIcon.check.view(size: HesiaIconSize.md)
                    .foregroundStyle(AYAColors.accent)
            case .none:
                EmptyView()
            }
        }
        .accessibilityHidden(true)
    }
}

/// Settings row that opens an external URL.
struct SettingsLinkRow: View {
    let icon: SettingsRowIcon
    let titleKey: LocalizedStringKey
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: AYASpacing.md) {
                SettingsRowLabel(icon: icon, titleKey: titleKey)
                SettingsRowAccessory.externalLink
            }
            .padding(.horizontal, AYASpacing.lg)
            .frame(minHeight: SettingsRowMetrics.minHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Settings row carrying a trailing toggle.
struct SettingsToggleRow: View {
    let icon: SettingsRowIcon
    let titleKey: LocalizedStringKey
    var value: SettingsRowValue?
    @Binding var isOn: Bool
    var isEnabled: Bool = true

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsRowLabel(icon: icon, titleKey: titleKey, value: value)
        }
        .tint(AYAColors.accent)
        .disabled(!isEnabled)
        .padding(.horizontal, AYASpacing.lg)
        .padding(.vertical, AYASpacing.md)
        .frame(minHeight: value == nil
            ? SettingsRowMetrics.minHeight
            : SettingsRowMetrics.stackedMinHeight)
    }
}

/// Static (non-interactive) settings row used for status readouts.
struct SettingsStatusRow: View {
    let icon: SettingsRowIcon
    let titleKey: LocalizedStringKey
    var value: SettingsRowValue?
    var accessory: SettingsRowAccessory = .none

    var body: some View {
        HStack(spacing: AYASpacing.md) {
            SettingsRowLabel(icon: icon, titleKey: titleKey, value: value)
            accessory
        }
        .padding(.horizontal, AYASpacing.lg)
        .frame(minHeight: value == nil
            ? SettingsRowMetrics.minHeight
            : SettingsRowMetrics.stackedMinHeight)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Settings rows") {
    ScrollView {
        VStack(alignment: .leading, spacing: AYASpacing.xl) {
            SettingsGroup {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(.themes),
                    titleKey: "settings.themes",
                    action: {}
                )
            }

            SettingsGroup("settings.profile.section") {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(.calendar),
                    titleKey: "cycle.settings.title",
                    value: SettingsRowValue("cycle.settings.edit"),
                    action: {}
                )
                SettingsRowSeparator()
                SettingsToggleRow(
                    icon: SettingsRowIcon(symbol: "faceid"),
                    titleKey: "settings.security.face_id.title",
                    value: SettingsRowValue("settings.security.face_id.description"),
                    isOn: .constant(true)
                )
            }
        }
        .padding(AYASpacing.xl)
    }
    .background(AYAColors.backgroundPrimary)
}
