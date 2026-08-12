import SwiftUI
import UIKit

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

    func hesiaInteractivePopGesture() -> some View {
        background {
            HESIAInteractivePopGestureInstaller()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    /// Provides the familiar leading-edge back gesture for a screen that is the
    /// root of its navigation stack and therefore cannot use UIKit's pop gesture.
    func hesiaRootEdgeBack(action: @escaping () -> Void) -> some View {
        modifier(HESIARootEdgeBackModifier(action: action))
    }
}

private struct HESIARootEdgeBackModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .global)
                .onEnded { value in
                    let beganAtLeadingEdge = value.startLocation.x <= 24
                    let movedRight = value.translation.width >= 72
                    let isPrimarilyHorizontal = abs(value.translation.width)
                        > abs(value.translation.height)
                    let hasForwardMomentum = value.predictedEndTranslation.width >= 120

                    guard
                        beganAtLeadingEdge,
                        isPrimarilyHorizontal,
                        movedRight || hasForwardMomentum
                    else { return }

                    action()
                }
        )
    }
}

private struct HESIAInteractivePopGestureInstaller: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> ResolverViewController {
        let controller = ResolverViewController()
        controller.resolve = { navigationController in
            context.coordinator.install(on: navigationController)
        }
        return controller
    }

    func updateUIViewController(_ controller: ResolverViewController, context: Context) {
        controller.resolve = { navigationController in
            context.coordinator.install(on: navigationController)
        }
        controller.resolveNavigationController()
    }

    final class ResolverViewController: UIViewController {
        var resolve: ((UINavigationController?) -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            resolveNavigationController()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            resolveNavigationController()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            resolveNavigationController()
        }

        func resolveNavigationController() {
            guard isViewLoaded, view.window != nil else { return }
            resolve?(
                navigationController
                    ?? parent?.navigationController
                    ?? findNavigationController(in: view.window?.rootViewController)
            )
        }

        private func findNavigationController(
            in controller: UIViewController?
        ) -> UINavigationController? {
            guard let controller else { return nil }
            if let navigationController = controller as? UINavigationController {
                return navigationController
            }
            if let presented = findNavigationController(in: controller.presentedViewController) {
                return presented
            }
            for child in controller.children.reversed() {
                if let navigationController = findNavigationController(in: child) {
                    return navigationController
                }
            }
            return nil
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var navigationController: UINavigationController?

        func install(on navigationController: UINavigationController?) {
            guard
                let navigationController,
                let gesture = navigationController.interactivePopGestureRecognizer
            else { return }

            self.navigationController = navigationController
            gesture.delegate = self
            gesture.isEnabled = true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController else { return false }
            return navigationController.viewControllers.count > 1
                && navigationController.transitionCoordinator == nil
        }
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
