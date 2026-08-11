import SwiftUI

enum HESIAMotion {
    static let screenDuration = 0.30
    static let playerDuration = 0.35
    static let reducedMotionDuration = 0.10

    static func screenTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .hesiaScreen
    }

    static func animation(
        reduceMotion: Bool,
        duration: Double = screenDuration
    ) -> Animation? {
        reduceMotion
            ? .linear(duration: reducedMotionDuration)
            : .easeInOut(duration: duration)
    }
}

extension AnyTransition {
    static var hesiaScreen: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985)),
            removal: .opacity
        )
    }
}

extension View {
    func ayaCardShadow() -> some View {
        shadow(color: AYAColors.shadow, radius: 9, x: 0, y: 5)
    }

    func ayaSelectionGlow(color: Color, isActive: Bool) -> some View {
        shadow(color: isActive ? color.opacity(0.28) : .clear, radius: 9, x: 0, y: 0)
    }

    func hesiaScreenTransition(reduceMotion: Bool) -> some View {
        transition(HESIAMotion.screenTransition(reduceMotion: reduceMotion))
    }

    func hesiaScreenAnimation<Value: Equatable>(
        reduceMotion: Bool,
        duration: Double = HESIAMotion.screenDuration,
        value: Value
    ) -> some View {
        animation(
            HESIAMotion.animation(reduceMotion: reduceMotion, duration: duration),
            value: value
        )
    }
}

struct HESIAMeditationTransitionContainer<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.985))
            .onAppear {
                guard !isVisible else { return }
                withAnimation(
                    HESIAMotion.animation(
                        reduceMotion: reduceMotion,
                        duration: HESIAMotion.playerDuration
                    )
                ) {
                    isVisible = true
                }
            }
    }
}
