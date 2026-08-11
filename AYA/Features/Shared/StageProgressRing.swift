import SwiftUI

struct StageProgressRing: View {
    let currentText: String
    let totalLabelKey: LocalizedStringKey
    let progress: Double
    let accessibilityLabelKey: LocalizedStringKey
    let accessibilityValue: String
    let trackColor: Color
    let progressColor: Color

    init(
        currentText: String,
        totalLabelKey: LocalizedStringKey,
        progress: Double,
        accessibilityLabelKey: LocalizedStringKey,
        accessibilityValue: String,
        trackColor: Color = AYAColors.softPink.opacity(0.34),
        progressColor: Color = AYAColors.primary
    ) {
        self.currentText = currentText
        self.totalLabelKey = totalLabelKey
        self.progress = progress
        self.accessibilityLabelKey = accessibilityLabelKey
        self.accessibilityValue = accessibilityValue
        self.trackColor = trackColor
        self.progressColor = progressColor
    }

    init(
        currentValue: Int,
        totalLabelKey: LocalizedStringKey,
        progress: Double,
        accessibilityLabelKey: LocalizedStringKey,
        accessibilityValue: String,
        trackColor: Color = AYAColors.softPink.opacity(0.34),
        progressColor: Color = AYAColors.primary
    ) {
        self.init(
            currentText: String(currentValue),
            totalLabelKey: totalLabelKey,
            progress: progress,
            accessibilityLabelKey: accessibilityLabelKey,
            accessibilityValue: accessibilityValue,
            trackColor: trackColor,
            progressColor: progressColor
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: 7)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text(verbatim: currentText)
                    .ayaTypography(.homeMetricValue)
                    .foregroundStyle(AYAColors.textPrimary)

                Text(totalLabelKey)
                    .ayaTypography(.homeMetadata)
                    .foregroundStyle(AYAColors.textTertiary)
            }
        }
        .frame(width: 112, height: 112)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelKey)
        .accessibilityValue(accessibilityValue)
    }
}
