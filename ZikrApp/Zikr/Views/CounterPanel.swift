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

/// The mint panel: tap anywhere on it to count.
struct CounterTapPanel: View {
    let count: Int
    /// Small line under the big number (e.g. the all-time total).
    let caption: String
    @Binding var fullScreen: Bool
    var celebrate: Bool = false
    let onTap: () -> Void
    let onReset: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.mint)

            VStack(spacing: 10) {
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.system(size: fullScreen ? 150 : 120, weight: .regular, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(count)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(caption)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
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
                withAnimation(.snappy) { fullScreen.toggle() }
            } label: {
                Image(systemName: fullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(18)
            }
            .accessibilityLabel(fullScreen ? "Show text" : "Full screen counter")

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
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Count \(count)")
        .accessibilityHint("Double-tap to count")
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
