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
                HStack(spacing: 0) {
                    timelineItems(expands: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        timelineItems(expands: false)
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

    @ViewBuilder
    private func timelineItems(expands: Bool) -> some View {
        ForEach(values, id: \.self) { value in
            LifeStageTimelineItem(
                text: value.description,
                isCurrent: value == currentValue,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                connectorColor: connectorColor,
                expands: expands
            )
        }
    }
}

private struct LifeStageTimelineItem: View {
    let text: String
    let isCurrent: Bool
    let activeColor: Color
    let inactiveColor: Color
    let connectorColor: Color
    let expands: Bool

    var body: some View {
        VStack(spacing: 7) {
            Text(verbatim: text)
                .ayaTypography(.homeMetadata)
                .foregroundStyle(isCurrent ? AYAColors.onAccent : AYAColors.textTertiary)
                .frame(width: 32, height: 32)
                .background(isCurrent ? activeColor : AYAColors.surface, in: Circle())
                .overlay {
                    if !isCurrent {
                        Circle().stroke(AYAColors.divider, lineWidth: 1)
                    }
                }

            ZStack {
                Rectangle()
                    .fill(connectorColor)
                    .frame(height: 1)

                Circle()
                    .fill(isCurrent ? activeColor : inactiveColor)
                    .frame(width: 9, height: 9)
            }
            .frame(width: expands ? nil : 39)
            .frame(maxWidth: expands ? .infinity : nil)
        }
        .frame(maxWidth: expands ? .infinity : nil)
    }
}
