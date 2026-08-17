import SwiftUI

enum HESIAWatchColors {
    static let primary = Color(red: 0.60, green: 0.38, blue: 0.48)
    static let emphasis = Color(red: 0.42, green: 0.15, blue: 0.27)
    static let pregnancy = Color(red: 1.00, green: 0.92, blue: 0.78)
    static let softPink = Color(red: 0.93, green: 0.75, blue: 0.83)
    static let background = Color(red: 0.98, green: 0.96, blue: 0.96)
    static let surface = Color.white
    static let primaryText = emphasis
    static let secondaryText = emphasis.opacity(0.76)
    static let progressTrack = emphasis.opacity(0.14)

    // Watch-specific semantic surfaces. The warm dark canvas merges with the
    // bezel and preserves legibility for watchOS chrome; content stays light.
    static let canvas = Color(red: 0.12, green: 0.07, blue: 0.10)
    static let cardSurface = Color(red: 0.99, green: 0.97, blue: 0.95)
    static let onCanvas = Color(red: 0.98, green: 0.95, blue: 0.96)
    static let onCanvasSecondary = onCanvas.opacity(0.68)
    static let controlSurface = onCanvas.opacity(0.10)

}
