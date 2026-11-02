import SwiftUI
import AudioToolbox

/// Shared pieces of the counter screen: the black text card and the big mint tap panel.
struct CounterTextCard: View {
    let arabic: String
    let transliteration: String
    let translation: String
    let source: String
    var header: String? = nil
    @AppStorage("showTranslation") private var showTranslation = true
    @AppStorage("showTransliteration") private var showTransliteration = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let header {
                    Text(header)
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.mint)
                }
                DuaTextView(
                    arabic: arabic,
                    transliteration: transliteration,
                    translation: translation,
                    source: source,
                    arabicSize: arabic.count > 300 ? 24 : (arabic.count > 80 ? 30 : 38),
                    showTransliteration: showTransliteration,
                    showTranslation: showTranslation
                )
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

/// The mint panel: tap anywhere on it to count. Each tap sends out a soft ripple.
struct CounterTapPanel: View {
    let count: Int
    /// Small line under the big number (e.g. the all-time total).
    let caption: String
    @Binding var fullScreen: Bool
    var celebrate: Bool = false
    /// 0...1 progress through the current round, drawn as a thin bar.
    var progress: Double = 0
    let onTap: () -> Void
    let onReset: () -> Void

    @State private var ripples: [Ripple] = []

    private struct Ripple: Identifiable {
        let id = UUID()
        let point: CGPoint
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.mint, Theme.mintDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ForEach(ripples) { ripple in
                RippleView()
                    .position(ripple.point)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 10) {
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.system(size: fullScreen ? 150 : 120, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(count)))
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(caption)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
                    .contentTransition(.numericText())
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(12)
                }
                .accessibilityLabel("Reset")
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                withAnimation(.smooth) { fullScreen.toggle() }
            } label: {
                Image(systemName: fullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(18)
            }
            .accessibilityLabel(fullScreen ? "Show text" : "Full screen counter")

            if progress > 0 {
                GeometryReader { geo in
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .frame(width: max(8, geo.size.width * progress), height: 4)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .animation(.smooth, value: progress)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
                .allowsHitTesting(false)
            }

            if celebrate {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.25), in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 18)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { point in
            onTap()
            let ripple = Ripple(point: point)
            ripples.append(ripple)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                ripples.removeAll { $0.id == ripple.id }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Count \(count)")
        .accessibilityHint("Double-tap to count")
    }
}

/// A white ring that grows and fades where the panel was tapped.
private struct RippleView: View {
    @State private var expanded = false

    var body: some View {
        Circle()
            .fill(.white.opacity(expanded ? 0 : 0.35))
            .frame(width: 60, height: 60)
            .scaleEffect(expanded ? 4 : 0.3)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { expanded = true }
            }
    }
}

/// Small "swipe up" hint shown under the counter when there are more pages.
struct SwipeHint: View {
    let text: String
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "chevron.compact.up")
                .font(.title2)
                .offset(y: bounce ? -4 : 2)
            Text(text).font(.caption)
        }
        .foregroundStyle(.white.opacity(0.45))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { bounce = true }
        }
        .allowsHitTesting(false)
    }
}

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
