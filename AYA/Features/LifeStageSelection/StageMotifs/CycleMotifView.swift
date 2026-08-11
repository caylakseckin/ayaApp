import SwiftUI

struct CycleMotifView: View {
    var body: some View {
        Image("stage_cycle_orbit")
            .resizable()
            .scaledToFill()
            .scaleEffect(x: 1.05, y: 1.15)
            .overlay {
                LinearGradient(
                    colors: [AYAColors.secondary.opacity(0.72), AYAColors.primary.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.color)
            }
            .accessibilityHidden(true)
    }
}
