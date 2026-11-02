import SwiftUI

/// A stack of cards you swipe up, TikTok style. Swiping up flies the top card
/// away and the next one rises from behind; swiping down (when allowed) drops
/// the previous card back in from the top. Tapping a card also counts.
///
/// The deck only animates — the caller decides what "next" means and counts.
struct SwipeDeck<Card: View>: View {
    /// Identifies the top card; changing it resets the deck.
    let currentKey: AnyHashable
    var canGoBack = true
    /// Show a floating "+1" when a swipe counts.
    var showsPlusOne = true
    let onSwipeUp: () -> Void
    let onSwipeDown: () -> Void
    let onTap: () -> Void
    /// Builds a card: depth 0 is the top card, 1 is the one waiting behind it.
    @ViewBuilder let card: (_ depth: Int) -> Card

    @State private var offset: CGFloat = 0
    @State private var animating = false
    @State private var bursts: [UUID] = []

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let progress = min(1, max(0, -offset / max(1, height)))

            ZStack {
                // The waiting card grows into place as the top card leaves.
                card(1)
                    .scaleEffect(0.92 + 0.08 * progress)
                    .opacity(0.45 + 0.55 * progress)
                    .offset(y: 26 * (1 - progress))
                    .allowsHitTesting(false)

                card(0)
                    .offset(y: offset)
                    .rotation3DEffect(
                        .degrees(Double(offset / max(1, height)) * 18),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.6
                    )
                    .scaleEffect(1 - 0.04 * progress)
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !animating else { return }
                        onTap()
                        burst()
                    }
                    .gesture(drag(height: height))

                ForEach(bursts, id: \.self) { id in
                    PlusOneBurst()
                        .id(id)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: height)
        }
        .onChange(of: currentKey) {
            if !animating { offset = 0 }
        }
    }

    private func drag(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !animating else { return }
                let dy = value.translation.height
                // Resist pulling down when there's nothing to go back to.
                offset = dy > 0 ? (canGoBack ? dy * 0.6 : dy * 0.15) : dy
            }
            .onEnded { value in
                guard !animating else { return }
                let dy = value.translation.height
                let projected = value.predictedEndTranslation.height
                if dy < -90 || projected < -260 {
                    commitUp(height: height)
                } else if canGoBack && (dy > 110 || projected > 320) {
                    commitDown(height: height)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { offset = 0 }
                }
            }
    }

    private func commitUp(height: CGFloat) {
        animating = true
        withAnimation(.easeIn(duration: 0.22)) {
            offset = -height * 1.15
        } completion: {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                onSwipeUp()
                offset = 0
            }
            if showsPlusOne { burst() }
            animating = false
        }
    }

    private func commitDown(height: CGFloat) {
        animating = true
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            onSwipeDown()
            offset = -height
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            offset = 0
        } completion: {
            animating = false
        }
    }

    private func burst() {
        let id = UUID()
        bursts.append(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            bursts.removeAll { $0 == id }
        }
    }
}

/// "+1" that floats up and fades.
private struct PlusOneBurst: View {
    @State private var up = false

    var body: some View {
        Text("+1")
            .font(.system(size: 34, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: Theme.mintDeep.opacity(0.6), radius: 8)
            .offset(y: up ? -140 : 40)
            .opacity(up ? 0 : 1)
            .scaleEffect(up ? 1.2 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.85)) { up = true }
            }
    }
}

/// The zikr card used in the swipe modes: text on black, count on mint.
struct ZikrSwipeCard: View {
    let title: String
    let arabic: String
    let transliteration: String
    let translation: String
    let source: String
    let count: Int
    let target: Int
    var caption: String? = nil
    var header: String? = nil
    /// Bigger count area for the single-zikr mode.
    var countFocused = false
    @AppStorage("showTranslation") private var showTranslation = true
    @AppStorage("showTransliteration") private var showTransliteration = true
    @State private var showingFullText = false

    private var progress: Double {
        target > 0 ? min(1, Double(count) / Double(target)) : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Text: shrinks to fit, so the card never needs scrolling while you swipe.
            VStack(spacing: 14) {
                Text(header ?? title)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.mint)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if !arabic.isEmpty {
                    Text(arabic)
                        .font(Theme.arabicFont(size: arabic.count > 200 ? 26 : 36))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .minimumScaleFactor(0.3)
                        .environment(\.layoutDirection, .rightToLeft)
                } else {
                    Text(title)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                }
                if showTransliteration && !transliteration.isEmpty {
                    Text(transliteration)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(countFocused ? 3 : 5)
                }
                if showTranslation && !translation.isEmpty && !countFocused {
                    Text(translation)
                        .font(.callout.italic())
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(5)
                }
                Spacer(minLength: 0)
                HStack {
                    if !source.isEmpty {
                        Label(source, systemImage: "checkmark.seal")
                            .lineLimit(1)
                    }
                    Spacer()
                    if arabic.count > 200 {
                        Button("Full text") { showingFullText = true }
                            .foregroundStyle(Theme.mint)
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.card)

            // Count
            VStack(spacing: 6) {
                Text("\(count)")
                    .font(.system(size: countFocused ? 110 : 72, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(count)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(caption ?? (target > 0 ? "of \(target)" : "no target"))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
                if target > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.25))
                            Capsule().fill(.white).frame(width: max(6, geo.size.width * progress))
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 40)
                    .padding(.top, 6)
                }
            }
            .padding(.vertical, countFocused ? 34 : 22)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Theme.mint, Theme.mintDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.06)))
        .sheet(isPresented: $showingFullText) {
            ScrollView {
                DuaTextView(arabic: arabic, transliteration: transliteration, translation: translation, source: source)
                    .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

/// The two swipe modes, remembered between launches.
enum SwipeMode: String, CaseIterable, Identifiable {
    case feed, single
    var id: String { rawValue }

    var label: String {
        switch self {
        case .feed: return "Zikr feed"
        case .single: return "Single zikr"
        }
    }

    var symbol: String {
        switch self {
        case .feed: return "rectangle.stack"
        case .single: return "repeat"
        }
    }

    var hint: String {
        switch self {
        case .feed: return "Read, then swipe up — each swipe counts and shows your next zikr"
        case .single: return "Swipe up (or tap) to count"
        }
    }
}

/// Capsule switch between the two modes.
struct SwipeModePicker: View {
    @Binding var mode: SwipeMode
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SwipeMode.allCases) { option in
                Button {
                    withAnimation(.smooth(duration: 0.3)) { mode = option }
                } label: {
                    Label(option.label, systemImage: option.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(mode == option ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if mode == option {
                                Capsule().fill(Theme.mint).matchedGeometryEffect(id: "mode", in: selection)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.08), in: Capsule())
        .sensoryFeedback(.selection, trigger: mode)
    }
}
