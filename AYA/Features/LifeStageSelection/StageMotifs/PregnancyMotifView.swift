import SwiftUI

struct PregnancyMotifView: View {
    var body: some View {
        Image("stage_pregnancy_sprout")
            .resizable()
            .scaledToFill()
            .scaleEffect(x: 1.05, y: 1.15)
            .accessibilityHidden(true)
    }
}
