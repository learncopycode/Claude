import SwiftUI
import AudioToolbox

/// Vertical page dots on the right edge, like a feed position indicator.
struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        let shown = min(count, 9)
        let start = min(max(0, index - shown / 2), max(0, count - shown))
        VStack(spacing: 6) {
            ForEach(start..<(start + shown), id: \.self) { i in
                Capsule()
                    .fill(i == index ? Theme.mint : Color.white.opacity(0.25))
                    .frame(width: 4, height: i == index ? 18 : 6)
            }
        }
        .animation(.smooth, value: index)
        .allowsHitTesting(false)
    }
}

/// "484 left" pill shown at the top of the counter.
struct RemainingPill: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "target")
            .font(.headline.monospacedDigit())
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08)))
    }
}

/// Tap sound and haptics settings shared by all counters.
enum CounterFeedback {
    /// The soft keyboard "tock" (follows the silent switch).
    static func playTick() {
        AudioServicesPlaySystemSound(1104)
    }
}
