import SwiftUI

struct LifeStageHorizontalTimeline<Value: Hashable & CustomStringConvertible>: View {
    let values: [Value]
    let currentValue: Value
    let accessibilityLabelKey: LocalizedStringKey
    let activeColor: Color
    let inactiveColor: Color
    let connectorColor: Color
    let fillsAvailableWidth: Bool

    init(
        values: [Value],
        currentValue: Value,
        accessibilityLabelKey: LocalizedStringKey,
        activeColor: Color = AYAColors.secondary,
        inactiveColor: Color = AYAColors.tertiary,
        connectorColor: Color = AYAColors.softPink.opacity(0.34),
        fillsAvailableWidth: Bool = false
    ) {
        self.values = values
        self.currentValue = currentValue
        self.accessibilityLabelKey = accessibilityLabelKey
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
        self.connectorColor = connectorColor
        self.fillsAvailableWidth = fillsAvailableWidth
    }

    var body: some View {
        Group {
            if fillsAvailableWidth {
                ZStack {
                    timelineRail

                    HStack(spacing: 0) {
                        timelineItems(expands: true)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 2)
            } else {
                ScrollView(.horizontal) {
                    ZStack {
                        timelineRail

                        HStack(spacing: 7) {
                            timelineItems(expands: false)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelKey)
        .accessibilityValue(currentValue.description)
    }

    private var timelineRail: some View {
        Capsule()
            .fill(connectorColor)
            .frame(height: 1)
            .padding(.horizontal, AYASpacing.lg)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func timelineItems(expands: Bool) -> some View {
        ForEach(values, id: \.self) { value in
            LifeStageTimelineItem(
                text: value.description,
                isCurrent: value == currentValue,
                activeColor: activeColor,
                expands: expands
            )
        }
    }
}

private struct LifeStageTimelineItem: View {
    let text: String
    let isCurrent: Bool
    let activeColor: Color
    let expands: Bool

    var body: some View {
        Text(verbatim: text)
            .ayaTypography(.homeMetadata)
            .foregroundStyle(isCurrent ? AYAColors.onAccent : AYAColors.textTertiary)
            .frame(width: 32, height: 32)
            .background(isCurrent ? activeColor : AYAColors.surface, in: Circle())
            .overlay {
                if !isCurrent {
                    Circle().stroke(AYAColors.separator, lineWidth: 1)
                }
            }
            .frame(maxWidth: expands ? .infinity : nil)
    }
}
