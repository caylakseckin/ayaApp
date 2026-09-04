import SwiftUI

struct StageProgressRing: View {
    let currentText: String
    let totalLabelKey: LocalizedStringKey
    /// Pre-formatted denominator, used when it is dynamic — the cycle length
    /// varies per user, whereas pregnancy (40 weeks) and postpartum (90 days)
    /// are fixed and can use `totalLabelKey` directly. Formatted by the caller
    /// so this view stays free of localization plumbing.
    let totalLabelText: String?
    let progress: Double
    let accessibilityLabelKey: LocalizedStringKey
    let accessibilityValue: String
    let trackColor: Color
    let progressColor: Color

    @ScaledMetric(relativeTo: .title2) private var diameter: CGFloat = 112

    init(
        currentText: String,
        totalLabelKey: LocalizedStringKey,
        totalLabelText: String? = nil,
        progress: Double,
        accessibilityLabelKey: LocalizedStringKey,
        accessibilityValue: String,
        trackColor: Color = AYAColors.softPink.opacity(0.34),
        progressColor: Color = AYAColors.primary
    ) {
        self.currentText = currentText
        self.totalLabelKey = totalLabelKey
        self.totalLabelText = totalLabelText
        self.progress = progress
        self.accessibilityLabelKey = accessibilityLabelKey
        self.accessibilityValue = accessibilityValue
        self.trackColor = trackColor
        self.progressColor = progressColor
    }

    init(
        currentValue: Int,
        totalLabelKey: LocalizedStringKey,
        totalLabelText: String? = nil,
        progress: Double,
        accessibilityLabelKey: LocalizedStringKey,
        accessibilityValue: String,
        trackColor: Color = AYAColors.softPink.opacity(0.34),
        progressColor: Color = AYAColors.primary
    ) {
        self.init(
            currentText: String(currentValue),
            totalLabelKey: totalLabelKey,
            totalLabelText: totalLabelText,
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
                    .contentTransition(.numericText())

                totalLabel
                    .ayaTypography(.homeMetadata)
                    .foregroundStyle(AYAColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(AYASpacing.sm)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelKey)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var totalLabel: some View {
        if let totalLabelText {
            Text(verbatim: totalLabelText)
        } else {
            Text(totalLabelKey)
        }
    }
}
